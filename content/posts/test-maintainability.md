---
title: "博客可维护性测试"
date: 2026-08-08T14:09:29+08:00
draft: false
tags: ["测试"]
summary: "验证 Hugo 博客的可维护性——新文章能否正常发布。"
---

## 测试目标

这篇文章用 `hugo new content` 命令一键生成，只需要：
1. 改 `draft: false`
2. 写 Markdown 内容
3. 运行 `hugo --buildFuture`

全程不需要改任何模板或配置代码。

## 验证结果

如果你能看到这篇文章，说明博客的**内容发布流程**完全正常。以后要发新文章，重复这三步就行。
