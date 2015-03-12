# Introduction #

only Dataobject's URI can contain format string, format string always appear in URI's last level

Usually, dataobject's uri is like this : `"/ContainerA/ContainB/ContainD/ContainE/dataobject.format"`

Also, a dataobject's uri can without format : `"/ContainerA/dataobject"`

# Details #

URI通常起着唯一定址一个对象的作用，我假定format字符串是与对象的定址是有关的，例如：

如果请求的URI为`"/ContainerA/dataobject.format"`，最终用于定址的URI却为`"/ContainerA/dataobject.format"`

因此`"/ContainerA/dataobject.txt"`和`"/ContainerA/dataobject.jpg"`指向的是不同的dataobject

这也就意味着如果`ContainerA`下有一个对象名为`dataobject`、格式名为`.txt`的数据对象时，再想Create一个对象名为`dataobject`、格式名为`.jpg`数据对象也是可以的。