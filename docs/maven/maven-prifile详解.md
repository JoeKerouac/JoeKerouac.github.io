# maven使用
## profile的激活方式
示例文件：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository>${user.home}/.m2/repository</localRepository>

  <profiles>
  
    <profile>
      <id>ali</id>
      <activation>
        <property>
          <name>env</name>
          <value>ali</value>
        </property>
        <activeByDefault>true</activeByDefault>
      </activation>
      <repositories>
          <repository>
              <id>ali</id>
              <name>ali maven repository</name>
              <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
              <releases>
                  <enabled>true</enabled>
              </releases>
              <snapshots>
                  <enabled>false</enabled>
              </snapshots>
          </repository>
      </repositories>
      <pluginRepositories>
          <pluginRepository>
              <id>ali</id>
              <name>ali maven repository</name>
              <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
              <releases>
                  <enabled>true</enabled>
              </releases>
              <snapshots>
                  <enabled>false</enabled>
              </snapshots>
          </pluginRepository>
      </pluginRepositories>
    </profile>
    
    <profile>
       <id>ali2</id>
       <activation>
         <property>
           <name>env</name>
           <value>ali2</value>
         </property>
         <jdk>1.8</jdk>
       </activation>
       <repositories>
           <repository>
               <id>ali2</id>
               <name>ali maven repository</name>
               <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
               <releases>
                   <enabled>true</enabled>
               </releases>
               <snapshots>
                   <enabled>false</enabled>
               </snapshots>
           </repository>
       </repositories>
       <pluginRepositories>
           <pluginRepository>
               <id>ali2</id>
               <name>ali maven repository</name>
               <url>http://maven.aliyun.com/nexus/content/groups/public/</url>
               <releases>
                   <enabled>true</enabled>
               </releases>
               <snapshots>
                   <enabled>false</enabled>
               </snapshots>
           </pluginRepository>
       </pluginRepositories>
     </profile>

  </profiles>
</settings>

```
想要激活ali1，可以使用`-P ali`，或者使用`-P env=ali`
