# folder [![Build Status](https://travis-ci.org/getbpt/folder.svg?branch=master)](https://travis-ci.org/getbpt/folder) [![Coverage Status](https://img.shields.io/coveralls/github/getbpt/folder/master.svg)](https://coveralls.io/github/getbpt/folder) [![Go Report Card](https://goreportcard.com/badge/github.com/getbpt/folder)](https://goreportcard.com/report/github.com/getbpt/folder)

URL to folder name parser based on bpt rules

## Examples


```golang
folder.FromURL("git@github.com:getbpt/bpt.git")
// git-AT-github.com-COLON-getbpt-SLASH-bpt.git
```

```golang
folder.ToURL("https-COLON--SLASH--SLASH-github.com-SLASH-getbpt-SLASH-folder")
// https://github.com/getbpt/folder
```
