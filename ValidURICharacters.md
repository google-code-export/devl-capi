# Details #

`ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_,.`

下文所指的对象可以是`Container、Dataobject、Queue、Domain`中的任何一种

  * `'.'`若出现，只能在URI的最后一级是dataobject或Queue的URI中出现，标志着格式名的开始，不能在上层的任何一级目录名中出现。例如：
    1. 有效：`/containerA/containerB/dataobject.txt` _对象名 `"dataobject"` 格式名 `".txt"`_
    1. 有效：`/containerA/containerB/data,object` _对象名 `"data,object"` 格式名 `nil`_
    1. 有效：`/containerA/containerB/2009-6.4db` _对象名 `"2009-6"` 格式名 `".4db"`_
    1. 无效：`/containerA/contai.nerB/2009-6.4db` _对象名 `"2009-6"` 格式名 `".4db"`_
    1. 有效：`/containerA/containerB/_dataobject` _对象名 `"_dataobject"` 格式名 `nil`_
    1. 无效：`/contai.nerA/containerB/_dataobject` _对象名 `"_dataobject"` 格式名 `nil`_
    1. 对象名无效：`/containerA/containerB/_da.tao.bject` _对象名 `"_da.tao"` 格式名 `".bject"`_
    1. 对象名无效：`/containerA/containerB/-da,tao.bject` _对象名 `"-da,tao"` 格式名 `".bject"`_
    1. 格式名无效：`/containerA/containerB/_da,tao.b_ject` _对象名 `"_da,tao"` 格式名 `".b_ject"`_
  * 对象名可以由`"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_,"`中的任意字符以任意长度混合组成，但有一点限制：
    * **不能以`'-'`或`','`开头或结尾**
  * 格式名可以由`"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"`中的任意字符以任意长度混合组成