# JPM
Simples Build System


## Run

- Novo projeto: ```jpm new```

  * Running
  ```
  $ jpm new

  New project JPM
  [JPM] project name: hello
  [JPM] package name: com.github.jpm.hello   
  [JPM] main class: Hello
  
  2024-02-03 16:23:59 [JPM] building project hello
  2024-02-03 16:23:59 [JPM] created /home/danroxha/Workspace/hello/src/main/java/com/github/jpm/hello
  2024-02-03 16:23:59 [JPM] created /home/danroxha/Workspace/hello/src/main/java/com/github/jpm/hello/HelloApplication.java
  2024-02-03 16:24:00 [JPM] donwloaded JPM
  2024-02-03 16:24:00 [JPM] path: /home/danroxha/Workspace/hello

  ```

- Execução: ```jpm run```
  * Running
  ```
  2024-02-03 16:36:14 [JPM] dependency [loading] sqlite-jdbc-3.45.1.0.jar [https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.45.1.0/sqlite-jdbc-3.45.1.0.jar]
  2024-02-03 16:36:14 [JPM] dependency [loading] slf4j-api-1.7.36.jar [https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar]
  2024-02-03 16:36:17 waiting 2 of 2
  2024-02-03 16:36:17 [JPM] path /home/danroxha/Workspace/jpm/hello/.jpm/
  2024-02-03 16:36:17 [JPM] building /home/danroxha/Workspace/jpm/hello/src/main/java/com/github/jpm/hello/HelloApplication.java
  Hello JPM
  ```

# Dependências ```dependencies.txt```
- Suporte somente pra repositório Mavel Central
- Suporte para adição de dependência Gradle (Short)
  ```
  # Support to Gradle (Short). Only Central Repository
  # implementation 'aws.sdk.kotlin:aws-core-jvm:1.0.48'
  # 
  # // https://mvnrepository.com/artifact/org.keycloak/keycloak-core
  # implementation 'org.keycloak:keycloak-core:23.0.5'

  // https://mvnrepository.com/artifact/org.xerial/sqlite-jdbc
  implementation 'org.xerial:sqlite-jdbc:3.45.1.0'

  // https://mvnrepository.com/artifact/org.slf4j/slf4j-api
  implementation 'org.slf4j:slf4j-api:1.7.36'

  ```
