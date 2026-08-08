---
title: "Hugo 文章不显示的排查实录：一个时区引发的血案"
date: 2026-08-08T10:00:00+08:00
draft: false
tags: ["Hugo", "运维", "排错", "Linux"]
summary: "Hugo 明明识别了文章，页面却不生成 HTML？从模板查起，到翻文档、换版本，最终定位到时区问题——一个 date 字段引发的 3 小时排查全过程。"
---

## 现象

用 Hugo + Hugo Narrow 主题搭建技术博客，写完第一篇文章后运行 `hugo server`，发现：

- 文章列表页显示 **"0 个页面"**、"暂无内容"
- 直接访问文章 URL 返回 **404**
- 但 `hugo list all` 明明能看到文章

```
$ hugo list all
content/posts/hello-world/index.md  ...  page  posts  /posts/hello-world/
```

Hugo 知道这篇文章存在，死活不渲染 HTML。

## 排查过程

### 第一轮：怀疑模板

Hugo Narrow 是第三方主题，先怀疑主题的模板有问题。

- 检查 `themes/hugo-narrow/layouts/posts/single.html` → 存在
- 检查 `themes/hugo-narrow/layouts/_default/single.html` → 不存在（在根目录）
- 手动创建 `layouts/_default/single.html` → 无效

**排除模板问题。**

### 第二轮：怀疑 Hugo 版本

当前版本 Hugo v0.164.0，刚发布一个月。下载 v0.163.0 对比测试：

```bash
curl -sL "https://github.com/gohugoio/hugo/releases/download/v0.163.0/hugo_extended_0.163.0_windows-amd64.zip" -o hugo163.zip
/tmp/hugo163/hugo.exe
```

**两个版本现象一致。排除版本 bug。**

### 第三轮：怀疑多语言配置

Hugo Narrow 支持中英文多语言，可能语言配置干扰了内容渲染？

- 删除 `config/_default/languages.yaml` → 无效
- 删除 `defaultContentLanguage` 配置 → 无效
- 修改 `content/posts/hello-world/index.md` 为 `.zh-hans.md` → 无效

**排除多语言问题。**

### 第四轮：怀疑页面包（Page Bundle）

Hugo 的页面包格式 `content/posts/xxx/index.md` 可能在 Windows 上有兼容问题？

- 改为单文件 `content/posts/hello-world.md` → 无效
- 删除 `_index.md` → 无效
- 移到根目录 `content/hello.md` → 依然无效

**排除页面包问题。**

### 第五轮：对比实验

创建全新的 Hugo 项目，只放两篇文章——`content/about.md`（无日期）和 `content/posts/hello.md`（有日期）。

```
$ hugo
Pages: 7
```

访问首页，`.Site.RegularPages` 只渲染了一篇——**about**。hello 去哪了？

### 第六轮：关键发现

用 `hugo --templateMetrics` 发现：`single.html` 模板**根本没有被调用**。Hugo 主动跳过了文章渲染。

回头翻 Hugo 文档，看到一句话：

> Pages with a date in the future are not published by default.

检查文章的 Front Matter：

```yaml
date: 2026-08-08
```

当前时间是北京时间 2026-08-08 凌晨 2:40。

但 Hugo 把 `2026-08-08` 解析为 **UTC 时间**：`2026-08-08T00:00:00Z`！

而当前 UTC 时间是 `2026-08-07T18:40:00Z`——文章的发布时间还在 **5 个多小时后**！

```text
UTC 时间线：
  ┌──────────────────────┬──────────────────────┐
  │ 8月7日 18:40 (现在)   │ 8月8日 00:00 (文章)   │
  │ ←──────── 5h20m ────→│                      │
  └──────────────────────┴──────────────────────┘
  文章还在"未来" → Hugo 默认不渲染未来文章
```

### 第七轮：验证

加 `--buildFuture` 标志：

```
$ hugo --buildFuture
Pages: 8

$ cat public/index.html
<a href="/posts/hello/">Hello</a>
<a href="/about/">About</a>
```

**全部出来了。**

## 根因

```
date: 2026-08-08          ← Hugo 当作 UTC 零点
北京时间 UTC+8              ← 本地时间比 UTC 快 8 小时
当前 UTC 还是 8月7日        ← 文章还在"未来"
→ Hugo 过滤掉未来文章       ← 不渲染、不出现在任何列表
```

而 `content/about.md` 没有写 `date` 字段，所以不受影响——这也是为什么 about 页面一直正常。

## 修复

三种方案：

### 方案一：日期加时区（推荐）

```yaml
date: 2026-08-08T08:00:00+08:00
```

明确告诉 Hugo 这是东八区时间。

### 方案二：构建时加 `--buildFuture`

```bash
hugo --buildFuture
```

### 方案三：用昨天日期写文章

```yaml
date: 2026-08-07
```

UTC 的昨天肯定在 UTC 的今天之前，永远不会被过滤。

## 经验教训

1. **时间永远是编程里最容易出 bug 的东西**——时区、UTC、本地时间，随便一个都能坑你几个小时
2. **Hugo 的未来文章过滤是默认行为**，不是 bug，是 feature——但文档里一笔带过，很容易踩坑
3. **写 Front Matter 日期一定带时区**：`2026-08-08T08:00:00+08:00`，别偷懒只写 `2026-08-08`
4. **排查问题时，对比实验是最快的方法**——缩小范围到最小可复现场景，能排除 90% 的噪音
5. **`hugo --templateMetrics`** 是个好东西，能直观看到哪些模板被调用了、哪些没被调用

---

*排查耗时：3 小时 | 实际修复：1 分钟 | 经验价值：无价*
