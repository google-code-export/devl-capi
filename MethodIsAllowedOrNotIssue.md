# Introduction #

对一个发过来的请求中的URI和HTTP方法`(GET|PUT|POST|DELETE)`，能否对这个URI对应的对象执行这个方法的问题。

你需要了解CRUD和4个HTTP方法的对应关系，求详细的可以看这个→ http://en.wikipedia.org/wiki/Create,_read,_update_and_delete

我假定对应关系是下表这样的：
| HTTP方法 | CRUD |
|:-----------|:-----|
| `GET` | `Read` |
| `PUT` | `Create或Update` |
| `POS`T | `Create` |
| `DELETE` | `Delete`|

**# Details #**

首先，我假定根目录是`'/'`

  * 如果一个URI是以`'/'`结尾，那通常情况下不允许做`GET|PUT|DELETE`操作（有例外，下文会讲到），`POST`则可以，如果URI所指对象是一个`Container`的话`POST`操作会在下一级目录`Create`一个对象。例如：
    1. `"POST /ContainerA/ContainerX/"` 会`Create`一个`object`(其所属类别根据Http Request Header中的具体内容确定)，其URI为`"/ContainerA/ContainerX/newobject"`
    1. `"POST /ContainerA/ContainerX/newobject/"` `POST`操作会被允许，但创建`object`失败，因为虽然`newobject`存在，但`newobject`不是一个`Container`
  * 如果一个URI是以除`'/'`以外的任何一个有效字符结尾，则任何情况下都不允许做`POST`操作，`GET|PUT|DELETE`则可以。例如：`"/ContainerA/../ContainerX/Object"`
  * 如果一个URI是以`'/'`结尾，并且这个URI就是根目录`'/'`，则允许做`GET|PUT|POST`操作，对应的过程为`Read`根目录、`Update`根目录、在根目录下`Create`一个对象，例如：
    1. `"POST /"` 会`Create`一个`object`，其URI为`"/newobject"`