<a id="dockerfile-reference"></a>
# Referência do Dockerfile


O Docker pode criar imagens automaticamente lendo as instruções de um Dockerfile. Um Dockerfile é um documento de texto que contém todos os comandos que um usuário pode chamar na linha de comando para montar uma imagem. Esta página descreve os comandos que você pode usar em um Dockerfile.

<a id="overview"></a>
## Visão geral

O Dockerfile suporta as seguintes instruções:

| Instrução                            | Descrição                                                 |
| :------------------------------------- | :---------------------------------------------------------- |
| [`ADD`](#add)                          | Adicione arquivos e diretórios locais ou remotos.                  |
| [`ARG`](#arg)                          | Use variáveis de tempo de compilação.                                   |
| [`CMD`](#cmd)                          | Especificar comandos padrão.                                   |
| [`COPY`](#copy)                        | Copia arquivos e diretórios.                                 |
| [`ENTRYPOINT`](#entrypoint)            | Especificar o executável padrão.                                 |
| [`ENV`](#env)                          | Defina variáveis de ambiente.                                  |
| [`EXPOSE`](#expose)                    | Descreva em quais portas seu aplicativo está ouvindo.      |
| [`FROM`](#from)                        | Crie um novo estágio de compilação a partir de uma imagem base.                 |
| [`HEALTHCHECK`](#healthcheck)          | Verifique a saúde de um contêiner na inicialização.                      |
| [`LABEL`](#label)                      | Adicione metadados a uma imagem.                                   |
| [`MAINTAINER`](#maintainer-deprecated) | Especifique o autor de uma imagem.                             |
| [`ONBUILD`](#onbuild)                  | Especificar instruções para quando a imagem é usada em uma compilação. |
| [`RUN`](#run)                          | Executar comandos de compilação.                                     |
| [`SHELL`](#shell)                      | Defina o shell padrão de uma imagem.                          |
| [`STOPSIGNAL`](#stopsignal)            | Especifique o sinal de chamada do sistema para sair de um contêiner.     |
| [`USER`](#user)                        | Defina o ID do usuário e do grupo.                                      |
| [`VOLUME`](#volume)                    | Crie pontos de montagem de volume.                                       |
| [`WORKDIR`](#workdir)                  | Altera o diretório de trabalho.                                   |

<a id="format"></a>
## Formatação

Aqui está o formato do Dockerfile:

```dockerfile
# Comment
INSTRUCTION arguments
```

As instruções não diferenciam maiúsculas de minúsculas. No entanto, por convenção, elas são escritas em MAIÚSCULAS para facilitar sua distinção dos argumentos.

O Docker executa instruções em um Dockerfile em ordem. Um Dockerfile **deve começar com uma instrução `FROM`**. Isso pode ser depois [diretivas de analisadores](#parser-directives), [comentários](#format), e globalmente com escopo [ARGs](#arg). A instrução `FROM` especifica a [imagem base](https://docs.docker.com/glossary/#base-image) de onde você está construindo. `FROM` só pode ser precedido de um ou mais `ARG` instruções, que declaram argumentos que são usados em `FROM` linhas no Dockerfile.

BuildKit trata linhas que começam com `#` como comentário, a menos que a linha seja uma diretiva válida [parser](#parser-directives). A `#` marcador em qualquer outro lugar em uma linha é tratado como um argumento. Isso permite declarações como:

```dockerfile
# Comment
RUN echo 'we are running some # of cool things'
```

As linhas de comentário são removidas antes que as instruções do Dockerfile sejam executadas. O comentário no exemplo a seguir é removido antes do shell executar o comando `echo`.

```dockerfile
RUN echo hello \
# comment
world
```

Os exemplos a seguir são equivalentes.

```dockerfile
RUN echo hello \
world
```

Comentários não suportam caracteres de continuação de linha.

> [!NOTE]
> **Nota no espaço em branco**
>
> Para compatibilidade com versões anteriores, lidera o espaço em branco antes dos comentários (`#`) e instruções (como `RUN`) são ignorados, mas desencorajados. O espaço em branco líder não é preservado nesses casos, e os seguintes exemplos são, portanto, equivalentes:
>
> ```dockerfile
>         # this is a comment-line
>     RUN echo hello
> RUN echo world
> ```
>
> ```dockerfile
> # this is a comment-line
> RUN echo hello
> RUN echo world
> ```
>
> O espaço em branco em argumentos de instrução, no entanto, não é ignorado. O exemplo a seguir imprime `    hello    world` com espaço em branco principal como especificado:
>
> ```dockerfile
> RUN echo "\
>      hello\
>      world"
> ```

<a id="parser-directives"></a>
## Diretivas de analisador

As diretivas de analisador são opcionais e afetam a maneira pela qual as linhas subsequentes em um Dockerfile são tratadas. As diretivas de analisador não adicionam camadas à compilação e não aparecem como etapas de compilação. As diretivas de analisador são escritas como um tipo especial de comentário na forma `# directive=value`. Uma única diretiva só pode ser utilizada uma vez.

São apoiadas as seguintes diretivas de analisador:

- [`syntax`](#syntax)
- [`escape`](#escape)
- [`check`](#check) (desde o Dockerfile v1.8.0)

Uma vez que um comentário, linha vazia ou instrução de construtor foi processado, o BuildKit não procura mais por diretivas de analisador. Em vez disso, trata qualquer coisa formatada como uma diretiva de analisador como um comentário e não tenta validar se pode ser uma diretiva de analisador. Portanto, todas as diretivas de analisadores devem estar no topo de um Dockerfile.

Chaves de diretiva de analisadores, como `syntax` ou `check`, não diferenciam maiúsculas de minúsculas, mas são minúsculas por convenção. Os valores de uma diretiva diferenciam maiúsculas de minúsculas e devem ser escritos no caso adequado para a diretiva. Por exemplo, `#check=skip=jsonargsrecommended` é inválido porque o nome de verificação deve usar o caso Pascal, não minúscula. Também é convencional incluir uma linha em branco seguindo quaisquer diretivas de analisadores. Os caracteres de continuação de linha não são suportados em diretivas de analisadores.

Devido a essas regras, os seguintes exemplos são todos inválidos:

Inválido devido à continuação da linha:

```dockerfile
# direc \
tive=value
```

Inválido devido a aparecer duas vezes:

```dockerfile
# directive=value1
# directive=value2

FROM ImageName
```

Tratado como um comentário porque aparece depois de uma instrução de construtor:

```dockerfile
FROM ImageName
# directive=value
```

Tratado como um comentário porque aparece depois de um comentário que não é uma diretiva de análise:

```dockerfile
# About my dockerfile
# directive=value
FROM ImageName
```

O seguinte `unknowndirective` é tratado como um comentário porque não é reconhecido. O conhecido `syntax` diretiva é tratada como um comentário porque aparece depois de um comentário que não é uma diretiva de análise.

```dockerfile
# unknowndirective=value
# syntax=value
```

O espaço em branco não de quebra de linha é permitido em uma diretiva de analisador. Assim, as seguintes linhas são todas tratadas de forma idêntica:

```dockerfile
#directive=value
# directive =value
#	directive= value
# directive = value
#	  dIrEcTiVe=value
```

<a id="syntax"></a>
### Sintaxe

<a name="external-implementation-features"><!-- included for deep-links to old section --></a>

Use o `syntax` diretiva de analisador para declarar a versão de sintaxe do Dockerfile para usar na compilação. Se não especificado, o BuildKit usa uma versão agrupada do frontend do Dockerfile. A declaração de uma versão de sintaxe permite que você use automaticamente a versão mais recente do Dockerfile sem precisar atualizar o BuildKit ou o Docker Engine ou até mesmo usar uma implementação personalizada do Dockerfile.

A maioria dos usuários vai querer definir esta diretiva analisadora para `docker/dockerfile:1`, o que faz com que o BuildKit puxe a versão estável mais recente da sintaxe do Dockerfile antes da compilação.

```dockerfile
# syntax=docker/dockerfile:1
```

Para obter mais informações sobre como a diretiva analisadora funciona, consulte [Sintaxe do Dockerfile personalizado](https://docs.docker.com/build/buildkit/dockerfile-frontend/).

<a id="escape"></a>
### escape

```dockerfile
# escape=\
```

Ou

```dockerfile
# escape=`
```

A diretiva `escape` define o caráter usado para escapar de caracteres em um Dockerfile. Se não for especificado, o caractere de escape padrão é `\`.

O caractere de fuga é usado tanto para escapar de caracteres em uma linha, quanto para escapar de uma nova linha. Isso permite que uma instrução Dockerfile abranda várias linhas. Observe que, independentemente de o `escape` a diretiva de analisador está incluída em um Dockerfile, escapar não é realizada em um `RUN` comando, exceto no final de uma linha.

Definindo o caractere de fuga para `` ` `` é especialmente útil em `Windows`, onde `\` é o separador de caminho de diretório. `` ` `` é consistente com [Windows PowerShell](https://technet.microsoft.com/en-us/library/hh847755.aspx).

Considere o exemplo a seguir que falharia de maneira não óbvia no Windows. O segundo `\` no final da segunda linha seria interpretado como uma fuga para a nova linha, em vez de um alvo da fuga do primeiro `\`. Da mesma forma, o `\` no final da terceira linha seria, supondo que na verdade fosse tratada como uma instrução, fazer com que fosse tratada como uma continuação de linha. O resultado deste Dockerfile é que a segunda e a terceira linhas são consideradas uma única instrução:

```dockerfile
FROM microsoft/nanoserver
COPY testfile.txt c:\\
RUN dir c:\
```

Resultados em:

```console
PS E:\myproject> docker build -t cmd .

Sending build context to Docker daemon 3.072 kB
Step 1/2 : FROM microsoft/nanoserver
 ---> 22738ff49c6d
Step 2/2 : COPY testfile.txt c:\RUN dir c:
GetFileAttributesEx c:RUN: The system cannot find the file specified.
PS E:\myproject>
```

Uma solução para o acima seria usar `/` como alvo de ambos os `COPY` instrução, e `dir`. No entanto, essa sintaxe é, na melhor das hipóteses, confusa, pois não é natural para caminhos no Windows e, na pior das hipóteses, é propensa a erros, pois nem todos os comandos no suporte do Windows `/` como o separador de caminho.

Adicionando o `escape` diretiva de analisador, o seguinte Dockerfile tem sucesso como esperado com o uso de semântica de plataforma natural para caminhos de arquivo no Windows:

```dockerfile
# escape=`

FROM microsoft/nanoserver
COPY testfile.txt c:\
RUN dir c:\
```

Resultados em:

```console
PS E:\myproject> docker build -t succeeds --no-cache=true .

Sending build context to Docker daemon 3.072 kB
Step 1/3 : FROM microsoft/nanoserver
 ---> 22738ff49c6d
Step 2/3 : COPY testfile.txt c:\
 ---> 96655de338de
Removing intermediate container 4db9acbb1682
Step 3/3 : RUN dir c:\
 ---> Running in a2c157f842f5
 Volume in drive C has no label.
 Volume Serial Number is 7E6D-E0F7

 Directory of c:\

10/05/2016  05:04 PM             1,894 License.txt
10/05/2016  02:22 PM    <DIR>          Program Files
10/05/2016  02:14 PM    <DIR>          Program Files (x86)
10/28/2016  11:18 AM                62 testfile.txt
10/28/2016  11:20 AM    <DIR>          Users
10/28/2016  11:20 AM    <DIR>          Windows
           2 File(s)          1,956 bytes
           4 Dir(s)  21,259,096,064 bytes free
 ---> 01c7f3bef04f
Removing intermediate container a2c157f842f5
Successfully built 01c7f3bef04f
PS E:\myproject>
```

<a id="check"></a>
### check

```dockerfile
# check=skip=<checks|all>
# check=error=<boolean>
```

A diretiva `check` é usada para configurar como [construir verificações](https://docs.docker.com/build/checks/) são avaliados. Por padrão, todas as verificações são executadas e as falhas são tratadas como avisos.

Você pode desativar verificações específicas usando `#check=skip=<check-name>`. Para especificar várias verificações para pular, separe-as com uma vírgula:

```dockerfile
# check=skip=JSONArgsRecommended,StageNameCasing
```

Para desativar todas as verificações, use `#check=skip=all`.

Por padrão, compila com falha de saída de verificações de compilação com um código de status zero, apesar dos avisos. Para fazer a compilação falhar nos avisos, defina `#check=error=true`.

```dockerfile
# check=error=true
```

> [!NOTE]
> Ao usar o `check` diretiva, com `error=true` opção, recomenda-se fixar a sintaxe [Dockerfile](#syntax) a uma versão específica. Caso contrário, sua compilação pode começar a falhar quando novas verificações são adicionadas nas versões futuras.

Para combinar ambos os `skip` e `error` opções, use um ponto-e-vírgula para separá-los:

```dockerfile
# check=skip=JSONArgsRecommended;error=true
```

Para ver todos os cheques disponíveis, consulte a referência [construir verificações](https://docs.docker.com/reference/build-checks/). Observe que as verificações disponíveis dependem da versão da sintaxe do Dockerfile. Para ter certeza de que você está recebendo as verificações mais atualizadas, use o [`syntax`](#syntax) diretiva para especificar a versão da sintaxe do Dockerfile para a versão estável mais recente.

<a id="environment-replacement"></a>
## Substituição de ambiente

Variáveis de ambiente (declaradas com [o `ENV` declaração](#env)) também pode ser usado em certas instruções como variáveis a serem interpretadas pelo Dockerfile. As fugas também são tratadas para incluir sintaxe semelhante a uma variável em uma instrução literalmente.

Variáveis de ambiente são apontadas no Dockerfile com `$variable_name` ou `${variable_name}`. Eles são tratados de forma equivalente e a sintaxe da chave é normalmente usada para resolver problemas com nomes de variáveis sem espaço em branco, como `${foo}_bar`.

O `${variable_name}` sintaxe também suporta alguns do padrão `bash` modificadores conforme especificado abaixo:

- `${variable:-word}` indica que se `variable` é definido e não-vazio então o resultado será esse valor. Se `variable` está indesentado ou vazio então `word` será o resultado.
- `${variable-word}` indica que se `variable` está definido (mesmo que vazio) então o resultado será esse valor. Se `variable` está desaparado então `word` será o resultado.
- `${variable:+word}` indica que se `variable` é definido e não-vazio então `word` será o resultado, caso contrário, o resultado é a cadeia vazia.
- `${variable+word}` indica que se `variable` está definido (mesmo que vazio) então `word` será o resultado, caso contrário, o resultado é a cadeia vazia.

As seguintes substituições de variáveis são suportadas em uma versão de pré-lançamento da sintaxe Dockerfile, ao usar o `# syntax=docker/dockerfile-upstream:master` diretiva de sintaxe no seu Dockerfile:

- `${variable#pattern}` remove a partida mais curta de `pattern` de `variable`, buscando desde o início da corda.

  ```bash
  str=foobarbaz echo ${str#f*b}     # arbaz
  ```

- `${variable##pattern}` remove a partida mais longa de `pattern` de `variable`, buscando desde o início da corda.

  ```bash
  str=foobarbaz echo ${str##f*b}    # az
  ```

- `${variable%pattern}` remove a partida mais curta de `pattern` de `variable`, buscando para trás do final da corda.

  ```bash
  string=foobarbaz echo ${string%b*}    # foobar
  ```

- `${variable%%pattern}` remove a partida mais longa de `pattern` de `variable`, buscando para trás do final da corda.

  ```bash
  string=foobarbaz echo ${string%%b*}   # foo
  ```

- `${variable/pattern/replacement}` substituir a primeira ocorrência de `pattern` em `variable` com `replacement`

  ```bash
  string=foobarbaz echo ${string/ba/fo}  # fooforbaz
  ```

- `${variable//pattern/replacement}` substitui todas as ocorrências de `pattern` em `variable` com `replacement`

  ```bash
  string=foobarbaz echo ${string//ba/fo}  # fooforfoz
  ```

Em todos os casos, `word` pode ser qualquer string, incluindo variáveis de ambiente adicionais.

`pattern` é um padrão glob onde `?` corresponde a qualquer único caractere e `*` qualquer número de caracteres (incluindo zero). Para combinar literal `?` e `*`, use uma fuga de backslash: `\?` e `\*`.

Você pode escapar de nomes de variáveis inteiras adicionando um `\` antes da variável: `\$foo` ou `\${foo}`, por exemplo, traduzir-se-á em `$foo` e `${foo}` literais respectivamente.

Exemplo (representação aparsada é exibida após o `#`):

```dockerfile
FROM busybox
ENV FOO=/bar
WORKDIR ${FOO}   # WORKDIR /bar
ADD . $FOO       # ADD . /bar
COPY \$FOO /quux # COPY $FOO /quux
```

As variáveis de ambiente são suportadas pela seguinte lista de instruções no Dockerfile:

- `ADD`
- `COPY`
- `ENV`
- `EXPOSE`
- `FROM`
- `LABEL`
- `STOPSIGNAL`
- `USER`
- `VOLUME`
- `WORKDIR`
- `ONBUILD` (quando combinado com uma das instruções suportadas acima)

Você também pode usar variáveis de ambiente com `RUN`, `CMD`, e `ENTRYPOINT` instruções, mas nesses casos a substituição de variáveis é tratada pelo shell de comando, não pelo construtor. Observe que as instruções usando o formulário exec não invocam um shell de comando automaticamente. Veja [Substituição variável](#variable-substitution).

A substituição de variáveis de ambiente usa o mesmo valor para cada variável ao longo de toda a instrução. Alterar o valor de uma variável só faz efeito nas instruções subsequentes. Considere o seguinte exemplo:

```dockerfile
ENV abc=hello
ENV abc=bye def=$abc
ENV ghi=$abc
```

- O valor de `def` tornando-se `hello`
- O valor de `ghi` tornando-se `bye`

<a id="dockerignore-file"></a>
## Arquivo .dockerignore

Você pode usar `.dockerignore` arquivo para excluir arquivos e diretórios do contexto de compilação. Para obter mais informações, consulte [.dockerignore file](https://docs.docker.com/build/building/context/#dockerignore-files).

<a id="shell-and-exec-form"></a>
## Formas shell e exec

O `RUN`, `CMD`, e `ENTRYPOINT` instruções todas têm duas formas possíveis:

- `INSTRUCTION ["executable","param1","param2"]` (forma exex)
- `INSTRUCTION command param1 param2` (forma de casca)

O formulário exec torna possível evitar a troca de string de shell e invocar comandos usando um shell de comando específico ou qualquer outro executável. Ele usa uma sintaxe de matriz JSON, onde cada elemento no array é um comando, sinalizada ou argumento.

A forma de shell é mais relaxada e enfatiza a facilidade de uso, flexibilidade e legibilidade. O formulário shell usa automaticamente um shell de comando, enquanto o formulário exec não.

<a id="exec-form"></a>
### Forma exec

O formulário exec é analisado como um array JSON, o que significa que você deve usar double-quotes (") em torno de palavras, não single-quotes (').

```dockerfile
ENTRYPOINT ["/bin/bash", "-c", "echo hello"]
```

O formulário exec é melhor utilizado para especificar uma instrução `ENTRYPOINT`, combinada com `CMD` para definir argumentos padrão que podem ser substituídos em tempo de execução. Para mais informações, consulte [ENTRYPOINT](#entrypoint).

<a id="variable-substitution"></a>
#### Substituição variável

Usar o formulário exec não invoca automaticamente um shell de comando. Isso significa que o processamento normal de shell, como a substituição variável, não acontece. Por exemplo, `RUN [ "echo", "$HOME" ]` não lidará com a substituição variável para `$HOME`.

Se você quiser processamento de shell, use o formulário shell ou execute um shell diretamente com o formulário exec, por exemplo: `RUN [ "sh", "-c", "echo $HOME" ]`. Ao usar o formulário executivo e executar um shell diretamente, como no caso do shell, é o shell que está fazendo a substituição da variável de ambiente, não o construtor.

<a id="backslashes"></a>
#### Barras invertidas

Na forma executiva, você deve escapar de barras. Isso é particularmente relevante no Windows, onde a barra é o separador de caminho. A seguinte linha seria tratada como forma de shell devido a não ser válido JSON, e falhar de forma inesperada:

```dockerfile
RUN ["c:\windows\system32\tasklist.exe"]
```

A sintaxe correta para este exemplo é:

```dockerfile
RUN ["c:\\windows\\system32\\tasklist.exe"]
```

<a id="shell-form"></a>
### Forma shell

Ao contrário do formulário exec, as instruções que usam o formulário shell sempre usam um shell de comando. O formulário shell não usa o formato JSON array, em vez disso, é uma string regular. A string de formulário de shell permite escapar de newlines usando o [escape character](#escape) (backslash por padrão) para continuar uma única instrução na próxima linha. Isso torna mais fácil de usar com comandos mais longos, porque permite dividi-los em várias linhas. Por exemplo, considere estas duas linhas:

```dockerfile
RUN source $HOME/.bashrc && \
echo $HOME
```

Eles são equivalentes à seguinte linha:

```dockerfile
RUN source $HOME/.bashrc && echo $HOME
```

Você também pode usar o heredocs com o formulário shell para quebrar comandos suportados.

```dockerfile
RUN <<EOF
  source $HOME/.bashrc
  echo $HOME
EOF
```

Para mais informações sobre o heredocs, consulte [Aqui-documentos](#here-documents).

<a id="use-a-different-shell"></a>
### Usar outro shell

Você pode alterar o shell padrão usando o comando `SHELL`. Por exemplo:

```dockerfile
SHELL ["/bin/bash", "-c"]
RUN echo hello
```

Para mais informações, consulte [SHELL](#shell).

<a id="from"></a>
## FROM

```dockerfile
FROM [--platform=<platform>] <image> [AS <name>]
```

Ou

```dockerfile
FROM [--platform=<platform>] <image>[:<tag>] [AS <name>]
```

Ou

```dockerfile
FROM [--platform=<platform>] <image>[@<digest>] [AS <name>]
```

A instrução `FROM` inicializa um novo estágio de construção e define a [imagem base](https://docs.docker.com/glossary/#base-image) para instruções posteriores. Como tal, um Dockerfile válido deve começar com uma instrução `FROM`. A imagem pode ser qualquer imagem válida.

- `ARG` é a única instrução que pode preceder `FROM` no Dockerfile. Veja [Entenda como ARG e FROM interagir](#understand-how-arg-and-from-interact).
- `FROM` pode aparecer várias vezes dentro de um único Dockerfile para criar várias imagens ou usar um estágio de compilação como uma dependência para outro. Basta fazer uma anotação da última saída de ID de imagem pelo commit antes de cada novo `FROM` instrução. Cada uma instrução `FROM` limpa qualquer estado criado por instruções anteriores.
- Opcionalmente, um nome pode ser dado a um novo estágio de compilação, adicionando `AS name` para o `FROM` instrução. O nome pode ser usado em subseqüente `FROM <name>`, [`COPY --from=<name>`](#copy---from), e [`RUN --mount=type=bind,from=<name>`](#run---mounttypebind) instruções para se referir à imagem construída nesta etapa.

  Usar um estágio de compilação anterior como base para um estágio subsequente é um padrão comum para compartilhar um ambiente de base comum:

  ```dockerfile
  FROM ubuntu AS base
  RUN apt-get update && apt-get install -y shared-tooling

  FROM base AS dev
  RUN apt-get install -y dev-tooling

  FROM base AS prod
  COPY --from=build /app /app
  ```
- O `tag` ou `digest` valores são opcionais. Se você omitir qualquer um deles, o construtor assume uma `latest` tag por padrão. O construtor retorna um erro se não conseguir encontrar o `tag` valor.

O opcional `--platform` bandeira pode ser usada para especificar a plataforma da imagem no caso `FROM` faz referência a uma imagem multiplataforma. Por exemplo, `linux/amd64`, `linux/arm64`, ou `windows/amd64`. Por padrão, a plataforma de destino da solicitação de compilação é usada. Os argumentos de compilação global podem ser usados no valor dessa bandeira, por exemplo [ARGs de plataforma automática](#automatic-platform-args-in-the-global-scope) permitir que você force um estágio para plataforma de construção nativa (`--platform=$BUILDPLATFORM`), e usá-lo para cruzar-compilar para a plataforma de destino dentro do estágio.

<a id="understand-how-arg-and-from-interact"></a>
### Entenda como ARG e FROM interagem

`FROM` instruções suportam variáveis que são declaradas por qualquer `ARG` instruções que ocorrem antes da primeira `FROM`.

```dockerfile
ARG  CODE_VERSION=latest
FROM base:${CODE_VERSION}
CMD  /code/run-app

FROM extras:${CODE_VERSION}
CMD  /code/run-extras
```

Um `ARG` declarado antes de a `FROM` está fora de um estágio de construção, por isso não pode ser usado em qualquer instrução após um `FROM`. Para usar o valor padrão de um `ARG` declarado antes do primeiro `FROM` usar uma instrução `ARG` sem um valor dentro de uma etapa de construção:

```dockerfile
ARG VERSION=latest
FROM busybox:$VERSION
ARG VERSION
RUN echo $VERSION > image_version
```

<a id="run"></a>
## RUN

A instrução `RUN` irá executar quaisquer comandos para criar uma nova camada em cima da imagem atual. A camada adicionada é usada na próxima etapa no Dockerfile. `RUN` tem duas formas:

```dockerfile
# Shell form:
RUN [OPTIONS] <command> ...
# Exec form:
RUN [OPTIONS] [ "<command>", ... ]
```

Para obter mais informações sobre as diferenças entre essas duas formas, consulte [formas de casca ou de esco](#shell-and-exec-form).

O formulário shell é mais comumente usado e permite que você quebre instruções mais longas em várias linhas, usando novas [escapes](#escape), ou com [herdeocs](#here-documents):

```dockerfile
RUN <<EOF
apt-get update
apt-get install -y curl
EOF
```

O disponível `[OPTIONS]` para o `RUN` instrução são:

| Opção                          | Versão mínima do Dockerfile |
|---------------------------------|----------------------------|
| [`--device`](#run---device)     | 1.14-laborações                  |
| [`--mount`](#run---mount)       |  1.2                                                |
| [`--network`](#run---network)   |  1.3                                                |
| [`--security`](#run---security) |  1.20                                              |

<a id="cache-invalidation-for-run-instructions"></a>
### Invalidação do cache para instruções RUN

O cache para `RUN` As instruções não são invalidadas automaticamente durante a próxima compilação. O cache para uma instrução como `RUN apt-get dist-upgrade -y` será reutilizado durante a próxima construção. O cache para `RUN` instruções podem ser invalidadas usando o `--no-cache` bandeira, por exemplo `docker build --no-cache`.

Veja o [Guia de Melhores Práticas do Dockerfile](https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/) para mais informações.

O cache para `RUN` instruções podem ser invalidadas por [`ADD`](#add) e [`COPY`](#copy) instruções.

<a id="run---device"></a>
### RUN --device

> [!NOTE]
> Ainda não disponível em sintaxe estável, use [`docker/dockerfile:1-labs`](#syntax) versão. Ele também precisa do BuildKit 0.20.0 ou posterior.

```dockerfile
RUN --device=name,[required]
```

`RUN --device` permite construir para solicitar [CDI dispositivos](https://github.com/moby/buildkit/blob/master/docs/cdi.md) para estar disponível para a etapa de construção.

> [!WARNING]
> O uso de `--device` é protegida pelo `device` direito, que precisa ser habilitado ao iniciar o buildkitd daemon com `--allow-insecure-entitlement device` sinalizar ou em [buildkitd config](https://github.com/moby/buildkit/blob/master/docs/buildkitd.toml.md), e para um pedido de compilação com [`--allow device` bandeira](https://docs.docker.com/engine/reference/commandline/buildx_build/#allow).

O dispositivo `name` é fornecido pela especificação CDI registrada no BuildKit.

No exemplo a seguir, vários dispositivos são registrados na especificação CDI para o `vendor1.com/device` fornecedor.

```yaml
cdiVersion: "0.6.0"
kind: "vendor1.com/device"
devices:
  - name: foo
    containerEdits:
      env:
        - FOO=injected
  - name: bar
    annotations:
      org.mobyproject.buildkit.device.class: class1
    containerEdits:
      env:
        - BAR=injected
  - name: baz
    annotations:
      org.mobyproject.buildkit.device.class: class1
    containerEdits:
      env:
        - BAZ=injected
  - name: qux
    annotations:
      org.mobyproject.buildkit.device.class: class2
    containerEdits:
      env:
        - QUX=injected
annotations:
  org.mobyproject.buildkit.device.autoallow: true
```

O formato de nome do dispositivo é flexível e aceita vários padrões para suportar várias configurações de dispositivos:

* `vendor1.com/device`: solicitar o primeiro dispositivo encontrado para este fornecedor
* `vendor1.com/device=foo`: solicitar um dispositivo específico
* `vendor1.com/device=*`: solicitar todos os dispositivos para este fornecedor
* `class1`: solicitar dispositivos por `org.mobyproject.buildkit.device.class` anotação

> [!NOTE]
> As anotações são suportadas pela especificação CDI desde 0.6.0.

> [!NOTE]
> Para permitir automaticamente todos os dispositivos registrados na especificação CDI, você pode definir o `org.mobyproject.buildkit.device.autoallow` anotação. Você também pode definir esta anotação para um dispositivo específico.

<a id="example-cuda-powered-llama-inference"></a>
#### Exemplo: Inferência LLaMA Movida A CUDA

Neste exemplo utilizamos o `--device` bandeira para correr `llama.cpp` inferência usando um dispositivo GPU NVIDIA através do CDI:

```dockerfile
# syntax=docker/dockerfile:1-labs

FROM scratch AS model
ADD https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf /model.gguf

FROM scratch AS prompt
COPY <<EOF prompt.txt
Q: Generate  a list of 10 unique biggest countries by population in JSON with their estimated poulation in 1900 and 2024. Answer only newline formatted JSON with keys "country", "population_1900", "population_2024" with 10 items.
A:
[
    {

EOF

FROM ghcr.io/ggml-org/llama.cpp:full-cuda-b5124
RUN --device=nvidia.com/gpu=all \
    --mount=from=model,target=/models \
    --mount=from=prompt,target=/tmp \
    ./llama-cli -m /models/model.gguf -no-cnv -ngl 99 -f /tmp/prompt.txt
```

<a id="run---mount"></a>
### RUN --mount

```dockerfile
RUN --mount=[type=<TYPE>][,option=<value>[,option=<value>]...]
```

`RUN --mount` permite criar montagens do sistema de arquivos que a compilação pode acessar. Isso pode ser usado para:

- Criar a montagem de vínculo para o sistema de arquivos host ou outras etapas de compilação
- Acesse segredos de construção ou soquetes de ssh-agente
- Use um cache de gerenciamento de pacotes persistente para acelerar sua compilação

Os tipos de montagem suportados são:

| Tipo                                     | Descrição                                                                                                              |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| [`bind`](#run---mounttypebind) (default) | Diretórios de contexto de montagem de ligação (apenas leitura).                                                                              |
| [`cache`](#run---mounttypecache)         | Monte um diretório temporário para armazenar em cache diretórios para compiladores e gerenciadores de pacotes.                                     |
| [`tmpfs`](#run---mounttypetmpfs)         | Monte a `tmpfs` no recipiente de construção.                                                                                  |
| [`secret`](#run---mounttypesecret)       | Permita que o contêiner de compilação acesse arquivos seguros, como chaves privadas, sem assá-los na imagem ou no cache de compilação. |
| [`ssh`](#run---mounttypessh)             | Permita que o contêiner de compilação acesse as chaves SSH via agentes SSH, com suporte para senhas.                               |

<a id="run---mounttypebind"></a>
### RUN --mount=type=bind

Esse tipo de montagem permite vincular arquivos ou diretórios ao contêiner de compilação. Uma montagem de ligação é somente leitura por padrão.

| Opção                             | Descrição                                                                                                                                   |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `target`, `dst`, `destination`[^1] | Caminho de montagem.                                                                                                                                   |
| `source`                           | Caminho da fonte no `from`. Inadimplência à raiz do `from`.                                                                                |
| `from`                             | Construa o nome do estágio, contexto ou imagem para a raiz da origem. Inadimplência ao contexto de construção.                                                |
| `rw`,`readwrite`                   | Permitir gravações na montagem. Os dados escritos serão descartados após o `RUN` instrução completa e não será comprometida com a camada de imagem. |


<a id="run---mounttypecache"></a>
### RUN --mount=type=cache

Esse tipo de montagem permite que o contêiner de compilação encane diretórios para compiladores e gerenciadores de pacotes.

| Opção                             | Descrição                                                                                                                                                                                                                                                                |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                               | ID opcional para identificar caches separados/diferentes. Inadimplência ao valor de `target`.                                                                                                                                                                                          |
| `target`, `dst`, `destination`[^1] | Caminho de montagem.                                                                                                                                                                                                                                                                |
| `ro`,`readonly`                    | Somente leitura se definido.                                                                                                                                                                                                                                                          |
| `sharing`                          | Um de `shared`, `private`, ou `locked`. Inadimplência para `shared`. A `shared` montagem em cache pode ser usada simultaneamente por vários escritores. `private` cria uma nova montagem se houver vários escritores. `locked` pausa o segundo escritor até que o primeiro libere a montagem. |
| `from`                             | Crie o nome do estágio, do contexto ou da imagem para usar como base da montagem do cache. Defaults para esvaziar diretório.                                                                                                                                                                      |
| `source`                           | Subtrato no `from` para montar. Inadimplência à raiz do `from`.                                                                                                                                                                                                        |
| `mode`                             | Modo de arquivo para novo diretório de cache no octal. Padrão `0755`.                                                                                                                                                                                                                |
| `uid`                              | ID do usuário para novo diretório de cache. Padrão `0`.                                                                                                                                                                                                                              |
| `gid`                              | ID do grupo para o novo diretório de cache. Padrão `0`.                                                                                                                                                                                                                             |

O conteúdo dos diretórios de cache persiste entre as invocações do construtor sem invalidar o cache de instruções. Montagens em cache só devem ser usadas para melhor desempenho. Sua compilação deve funcionar com qualquer conteúdo do diretório de cache, pois outra compilação pode substituir os arquivos ou o GC pode limpá-la se for necessário mais espaço de armazenamento.

<a id="example-cache-go-packages"></a>
#### Exemplo: cache Go pacotes

```dockerfile
# syntax=docker/dockerfile:1
FROM golang
RUN --mount=type=cache,target=/root/.cache/go-build \
  go build ...
```

<a id="example-cache-apt-packages"></a>
#### Exemplo: cache apt pacotes

```dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu
RUN rm -f /etc/apt/apt.conf.d/docker-clean; echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt-get update && apt-get --no-install-recommends install -y gcc
```

O Apt precisa de acesso exclusivo aos seus dados, portanto, os caches usam a opção `sharing=locked`, que irá certificar-se de várias compilações paralelas usando a mesma montagem de cache vai esperar um pelo outro e não acessar os mesmos arquivos de cache ao mesmo tempo. Você também pode usar `sharing=private` se você preferir ter cada compilação crie outro diretório de cache neste caso.

<a id="run---mounttypetmpfs"></a>
### RUN --mount=type=tmpfs

Este tipo de montagem permite a montagem `tmpfs` no recipiente de construção.

| Opção                             | Descrição                                           |
| ---------------------------------- | ----------------------------------------------------- |
| `target`, `dst`, `destination`[^1] | Caminho de montagem.                                           |
| `size`                             | Especificar um limite superior no tamanho do sistema de arquivos. |

<a id="run---mounttypesecret"></a>
### RUN --mount=type=secret

Esse tipo de montagem permite que o contêiner de compilação acesse valores secretos, como tokens ou chaves privadas, sem cozi-los na imagem.

Por padrão, o segredo é montado como um arquivo. Você também pode montar o segredo como uma variável de ambiente definindo o `env` opção.

| Opção                         | Descrição                                                                                                     |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `id`                           | identificação do segredo. Padrão para basename do caminho de destino.                                                      |
| `target`, `dst`, `destination` | Monte o segredo para o caminho especificado. Inadimplência para `/run/secrets/` + `id` se não estiver indefinido e se `env` também está indefinido. |
| `env`                          | Monte o segredo para uma variável de ambiente em vez de um arquivo, ou ambos. (desde o Dockerfile v1.10.0)              |
| `required`                     | Se definido para `true`, os erros de instrução quando o segredo não está disponível. Inadimplência para `false`.               |
| `mode`                         | Modo de arquivo para arquivo secreto no octal. Padrão `0400`.                                                             |
| `uid`                          | ID do usuário para arquivo secreto. Padrão `0`.                                                                           |
| `gid`                          | ID do grupo para arquivo secreto. Padrão `0`.                                                                          |

<a id="example-access-to-s3"></a>
#### Exemplo: acesso ao S3

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3
RUN pip install awscli
RUN --mount=type=secret,id=aws,target=/root/.aws/credentials \
  aws s3 cp s3://... ...
```

```console
$ docker buildx build --secret id=aws,src=$HOME/.aws/credentials .
```

<a id="example-mount-as-environment-variable"></a>
#### Exemplo: Montagem como variável de ambiente

O exemplo a seguir leva o segredo `API_KEY` e monta-o como uma variável de ambiente com o mesmo nome.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
RUN --mount=type=secret,id=API_KEY,env=API_KEY \
    some-command --token-from-env $API_KEY
```

Supondo que o `API_KEY` variável de ambiente é definida no ambiente de compilação, você pode construir isso com o seguinte comando:

```console
$ docker buildx build --secret id=API_KEY .
```

<a id="run---mounttypessh"></a>
### RUN --mount=type=ssh

Este tipo de montagem permite que o contêiner de compilação acesse as chaves SSH através de agentes SSH, com suporte para senhas.

| Opção                         | Descrição                                                                                    |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| `id`                           | ID de soquete ou chave do agente SSH. Inadimplência para "padrão".                                          |
| `target`, `dst`, `destination` | Caminho do soquete do agente SSH. Inadimplência para `/run/buildkit/ssh_agent.${N}`.                             |
| `required`                     | Se definido para `true`, as instruções erros quando a chave está indisponível. Inadimplência para `false`. |
| `mode`                         | Modo de arquivo para soquete no octal. Padrão `0600`.                                                 |
| `uid`                          | ID do usuário para soquete. Padrão `0`.                                                               |
| `gid`                          | ID do grupo para soquete. Padrão `0`.                                                              |

<a id="example-access-to-gitlab"></a>
#### Exemplo: acesso ao GitLab

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
RUN apk add --no-cache openssh-client
RUN mkdir -p -m 0700 ~/.ssh && ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
RUN --mount=type=ssh \
  ssh -q -T git@gitlab.com 2>&1 | tee /hello
# "Welcome to GitLab, @GITLAB_USERNAME_ASSOCIATED_WITH_SSHKEY" should be printed here
# with the type of build progress is defined as `plain`.
```

```console
$ eval $(ssh-agent)
$ ssh-add ~/.ssh/id_rsa
(Input your passphrase here)
$ docker buildx build --ssh default=$SSH_AUTH_SOCK .
```

Você também pode especificar um caminho para `*.pem` arquivo no host diretamente em vez de `$SSH_AUTH_SOCK`. No entanto, os arquivos pem com senhas não são suportados.

<a id="run---network"></a>
### RUN --network

```dockerfile
RUN --network=<TYPE>
```

`RUN --network` permite o controle sobre qual ambiente de rede o comando é executado.

Os tipos de rede suportados são:

| Tipo                                         | Descrição                            |
| -------------------------------------------- | -------------------------------------- |
| [`default`](#run---networkdefault) (default) | Executar na rede padrão.            |
| [`none`](#run---networknone)                 | Funcionar sem acesso à rede.            |
| [`host`](#run---networkhost)                 | Execute no ambiente de rede do host. |

<a id="run---networkdefault"></a>
### RUN --network=default

Equivalente a não fornecer um sinal de sinalização, o comando é executado na rede padrão para a compilação.

<a id="run---networknone"></a>
### RUN --network=none

O comando é executado sem acesso à rede (`lo` ainda está disponível, mas está isolado para este processo)

<a id="example-isolating-external-effects"></a>
#### Exemplo: isolamento de efeitos externos

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.6
ADD mypackage.tgz wheels/
RUN --network=none pip install --find-links wheels mypackage
```

`pip` só poderá instalar os pacotes fornecidos no tarfile, que podem ser controlados por um estágio de compilação anterior.

<a id="run---networkhost"></a>
### RUN --network=host

O comando é executado no ambiente de rede do host (semelhante ao `docker build --network=host`, mas numa base de per-instrução)

> [!WARNING]
> O uso de `--network=host` é protegida pelo `network.host` direito, que precisa ser habilitado ao iniciar o buildkitd daemon com `--allow-insecure-entitlement network.host` sinalizar ou em [buildkitd config](https://github.com/moby/buildkit/blob/master/docs/buildkitd.toml.md), e para um pedido de compilação com [`--allow network.host` bandeira](https://docs.docker.com/engine/reference/commandline/buildx_build/#allow).

<a id="run---security"></a>
### RUN --security

```dockerfile
RUN --security=<sandbox|insecure>
```

O modo de segurança padrão é `sandbox`. Com `--security=insecure`, o construtor executa o comando sem sandbox no modo inseguro, que permite executar fluxos que exigem privilégios elevados (por exemplo, containerd). Isso equivale a correr `docker run --privileged`.

> [!WARNING]
> Para acessar esse recurso, o direito `security.insecure` deve ser habilitado ao iniciar o daemon buildkitd com `--allow-insecure-entitlement security.insecure` sinalizar ou em [buildkitd config](https://github.com/moby/buildkit/blob/master/docs/buildkitd.toml.md), e para um pedido de compilação com [`--allow security.insecure` bandeira](https://docs.docker.com/engine/reference/commandline/buildx_build/#allow).

O modo de sandbox padrão pode ser ativado via `--security=sandbox`, mas isso não é nada.

<a id="example-check-entitlements"></a>
#### Exemplo: verificar direitos

```dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu
RUN --security=insecure cat /proc/self/status | grep CapEff
```

```text
#84 0.093 CapEff:	0000003fffffffff
```

<a id="cmd"></a>
## CMD

A instrução `CMD` define o comando a ser executado ao executar um contêiner de uma imagem.

Você pode especificar `CMD` instruções utilizando [shell ou formulários executivos](#shell-and-exec-form):

- `CMD ["executable","param1","param2"]` (forma exex)
- `CMD ["param1","param2"]` (exec form, como parâmetros padrão para `ENTRYPOINT`)
- `CMD command param1 param2` (forma de casca)

Só pode haver uma instrução `CMD` em um Dockerfile. Se você listar mais de um `CMD`, apenas o último faz efeito.

O propósito de uma `CMD` é fornecer padrões para um contêiner em execução. Esses padrões podem incluir um executável, ou podem omitir o executável, caso em que você deve especificar uma instrução `ENTRYPOINT` também.

Se você gostaria que seu contêiner executasse o mesmo executável toda vez, então você deve considerar o uso `ENTRYPOINT` em combinação com `CMD`. Ver [`ENTRYPOINT`](#entrypoint). Se o usuário especificar argumentos para `docker run` então eles irão substituir o padrão especificado em `CMD`, mas ainda usar o padrão `ENTRYPOINT`.

Se `CMD` é usado para fornecer argumentos padrão para o `ENTRYPOINT` instrução, tanto o `CMD` e `ENTRYPOINT` instruções devem ser especificadas no [exec formulário](#exec-form).

> [!NOTE]
> Não confunda `RUN` com `CMD`. `RUN` realmente executa um comando e comete o resultado; `CMD` não executa nada no momento da compilação, mas especifica o comando pretendido para a imagem.

<a id="label"></a>
## LABEL

```dockerfile
LABEL <key>=<value> [<key>=<value>...]
```

A instrução `LABEL` adiciona metadados a uma imagem. A `LABEL` é um par chave-valor. Para incluir espaços dentro de um `LABEL` valor, use citações e barras como faria na análise de linha de comando. Alguns exemplos de uso:

```dockerfile
LABEL "com.example.vendor"="ACME Incorporated"
LABEL com.example.label-with-value="foo"
LABEL version="1.0"
LABEL description="This text illustrates \
that label-values can span multiple lines."
```

Uma imagem pode ter mais de um rótulo. Você pode especificar vários rótulos em uma única linha. Antes do Docker 1.10, isso diminuiu o tamanho da imagem final, mas isso não é mais o caso. Você ainda pode optar por especificar vários rótulos em uma única instrução, de uma das duas maneiras a seguir:

```dockerfile
LABEL multi.label1="value1" multi.label2="value2" other="value3"
```

```dockerfile
LABEL multi.label1="value1" \
      multi.label2="value2" \
      other="value3"
```

> [!NOTE]
> Certifique-se de usar citações duplas e não citações simples. Principalmente quando você está usando a interpolação de string (e.g. `LABEL example="foo-$ENV_VAR"`), as citações simples tomarão a string como está sem desempacotar o valor da variável.

Etiquetas incluídas nas imagens base (imagens no `FROM` linha) são herdadas pela sua imagem. Se um rótulo já existe, mas com um valor diferente, o valor mais recentemente aplicado substitui qualquer valor previamente definido.

Em uma compilação de vários estágios, os rótulos de estágios intermediários só estão presentes na imagem final se o estágio final for direta ou indiretamente baseado neles (via `FROM`). Rótulos de um estágio com o qual você só faz referência `COPY --from` ou `RUN --mount=from=` não estão incluídos na imagem de saída. Etiquetas da imagem base especificada na final `FROM` instrução são sempre herdadas.

Para visualizar os rótulos de uma imagem, use o comando `docker image inspect`. Você pode usar o `--format` opção para mostrar apenas os rótulos;

```console
$ docker image inspect --format='{{json .Config.Labels}}' myimage
```

```json
{
  "com.example.vendor": "ACME Incorporated",
  "com.example.label-with-value": "foo",
  "version": "1.0",
  "description": "This text illustrates that label-values can span multiple lines.",
  "multi.label1": "value1",
  "multi.label2": "value2",
  "other": "value3"
}
```

<a id="maintainer-deprecated"></a>
## MAINTAINER (depreciado)

```dockerfile
MAINTAINER <name>
```

A instrução `MAINTAINER` define o campo _Autor_ das imagens geradas. A instrução `LABEL` é uma versão muito mais flexível disso e você deve usá-lo em vez disso, pois ele permite definir quaisquer metadados que você precisa, e pode ser visualizado facilmente, por exemplo com `docker inspect`. Para definir um rótulo correspondente ao `MAINTAINER` campo que você poderia usar:

```dockerfile
LABEL org.opencontainers.image.authors="SvenDowideit@home.org.au"
```

Isso será então visível de `docker inspect` com os outros rótulos.

<a id="expose"></a>
## EXPOSE

```dockerfile
EXPOSE <port> [<port>/<protocol>...]
```

O `EXPOSE` A instrução informa o Docker que o contêiner escuta nas portas de rede especificadas em tempo de execução. Você pode especificar se a porta é ouvida no TCP ou no UDP, e o padrão é TCP se você não especificar um protocolo.

O `EXPOSE` A instrução não publica o porto. Funciona como um tipo de documentação entre a pessoa que constrói a imagem e a pessoa que executa o contêiner, sobre quais portas se destinam a ser publicadas. Para publicar a porta ao executar o contêiner, use o `-p` bandeira em `docker run` para publicar e mapear uma ou mais portas, ou o `-P` sinalie para publicar todas as portas expostas e mapeá-las para portas de alta ordem.

Por padrão, `EXPOSE` assume o TCP. Você também pode especificar UDP:

```dockerfile
EXPOSE 80/udp
```

Para expor tanto no TCP quanto no UDP, inclua duas linhas:

```dockerfile
EXPOSE 80/tcp
EXPOSE 80/udp
```

Neste caso, se você usar `-P` com `docker run`, a porta será exposta uma vez para TCP e uma vez para UDP. Lembra-te disso `-P` usa uma porta de host de alta ordem efêmera no host, de modo que TCP e UDP não usam a mesma porta.

Independentemente do `EXPOSE` configurações, você pode sobrepor-los em tempo de execução usando o `-p` bandeira. Por exemplo

```console
$ docker run -p 80:80/tcp -p 80:80/udp ...
```

Para configurar o redirecionamento da porta no sistema host, consulte [usando o sinalizador -P](https://docs.docker.com/reference/cli/docker/container/run/#publish). O `docker network` suportes de comando criando redes para comunicação entre contêineres sem a necessidade de expor ou publicar portas específicas, porque os contêineres conectados à rede podem se comunicar entre si sobre qualquer porta. Para obter informações detalhadas, consulte a [visão geral deste recurso](https://docs.docker.com/engine/userguide/networking/).

<a id="env"></a>
## ENV

```dockerfile
ENV <key>=<value> [<key>=<value>...]
```

A instrução `ENV` define a variável ambiente `<key>` para o valor `<value>`. Este valor estará no ambiente para todas as instruções subsequentes no estágio de construção e pode ser [subescido inline](#environment-replacement) em muitos também. O valor será interpretado para outras variáveis de ambiente, portanto, os caracteres de cotação serão removidos se não forem escapados. Como a análise de linha de comando, aspas e backslashes podem ser usadas para incluir espaços dentro de valores.

Exemplo:

```dockerfile
ENV MY_NAME="John Doe"
ENV MY_DOG=Rex\ The\ Dog
ENV MY_CAT=fluffy
```

A instrução `ENV` permite múltiplos `<key>=<value> ...` variáveis a serem definidas ao mesmo tempo, e o exemplo abaixo produzirá os mesmos resultados líquidos na imagem final:

```dockerfile
ENV MY_NAME="John Doe" MY_DOG=Rex\ The\ Dog \
    MY_CAT=fluffy
```

As variáveis de ambiente definidas usando `ENV` persistirá quando um contêiner for executado a partir da imagem resultante. Você pode visualizar os valores usando `docker inspect`, e alterá-los usando `docker run --env <key>=<value>`.

Um estágio herda quaisquer variáveis de ambiente que foram definidas usando `ENV` por seu estágio pai ou qualquer ancestral. Consulte a seção [construções de vários estágios](https://docs.docker.com/build/building/multi-stage/) no manual para mais informações.

A persistência variável do ambiente pode causar efeitos colaterais inesperados. Por exemplo, configuração `ENV DEBIAN_FRONTEND=noninteractive` altera o comportamento de `apt-get`, e pode confundir os usuários da sua imagem.

Se uma variável de ambiente for necessária apenas durante a compilação e não na imagem final, considere definir um valor para um único comando:

```dockerfile
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ...
```

Ou usando [`ARG`](#arg), que não se persiste na imagem final:

```dockerfile
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y ...
```

> [!NOTE]
> **Sintaxe alternativa**
>
> A instrução `ENV` também permite uma sintaxe alternativa `ENV <key> <value>`, omitindo o `=`. Por exemplo:
>
> ```dockerfile
> ENV MY_VAR my-value
> ```
>
> Essa sintaxe não permite que várias variáveis de ambiente sejam definidas em uma única `ENV` instrução, e pode ser confusa. Por exemplo, o seguinte define uma única variável de ambiente (`ONE`) com valor `"TWO= THREE=world"`:
>
> ```dockerfile
> ENV ONE TWO= THREE=world
> ```
>
> A sintaxe alternativa é suportada para compatibilidade com versões anteriores, mas desencorajada pelas razões descritas acima e pode ser removida em uma versão futura.

<a id="add"></a>
## ADD

ADD tem duas formas. Este último formulário é necessário para caminhos que contenham espaço em branco.

```dockerfile
ADD [OPTIONS] <src> ... <dest>
ADD [OPTIONS] ["<src>", ... "<dest>"]
```

O disponível `[OPTIONS]` são:

| Opção                                  | Versão mínima do Dockerfile |
| --------------------------------------- | -------------------------- |
| [`--keep-git-dir`](#add---keep-git-dir) |  1.1                                                |
| [`--checksum`](#add---checksum)         |  1.6                                                |
| [`--chmod`](#add---chmod)               |  1.2                                                |
| [`--chown`](#add---chown)               |                                                                                    |
| [`--link`](#add---link)                 |  1.4                                                |
| [`--unpack`](#add---unpack)             |  1.17                                              |
| [`--exclude`](#add---exclude)           |  1.19                                              |

A instrução `ADD` copia novos arquivos ou diretórios de `<src>` e as adiciona ao sistema de arquivos da imagem no caminho `<dest>`. Arquivos e diretórios podem ser copiados do contexto de compilação, de uma URL remota ou de um repositório Git.

O `ADD` e `COPY` instruções são funcionalmente semelhantes, mas servem propósitos ligeiramente diferentes. Saiba mais sobre as [diferenças entre `ADD` e `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy).

<a id="source"></a>
### Fonte

Você pode especificar vários arquivos de origem ou diretórios com `ADD`. O último argumento deve ser sempre o destino. Por exemplo, para adicionar dois arquivos, `file1.txt` e `file2.txt`, do contexto de construção para `/usr/src/things/` no recipiente de construção:

```dockerfile
ADD file1.txt file2.txt /usr/src/things/
```

Se você especificar vários arquivos de origem, diretamente ou usando um curinga, o destino deve ser um diretório (deve terminar com um slash `/`).

Para adicionar arquivos de um local remoto, você pode especificar uma URL ou o endereço de um repositório Git como fonte. Por exemplo:

```dockerfile
ADD https://example.com/archive.zip /usr/src/things/
ADD git@github.com:user/repo.git /usr/src/things/
```

BuildKit detecta o tipo de `<src>` e processa-o em conformidade.

- Se `<src>` é um arquivo ou diretório local, o conteúdo do diretório são copiados para o destino especificado. Veja [Adição de arquivos do contexto de compilação](#adding-files-from-the-build-context).
- Se `<src>` é um arquivo de alcatrão local, é descomprimido e extraído para o destino especificado. Veja [Adicionando arquivos de alcatrão locais](#adding-local-tar-archives).
- Se `<src>` é uma URL, o conteúdo da URL é baixado e colocado no destino especificado. Veja [Adição de arquivos a partir de um URL](#adding-files-from-a-url).
- Se `<src>` é um repositório Git, o repositório é clonado para o destino especificado. Veja [Adiciando arquivos de um repositório do Git](#adding-files-from-a-git-repository).

<a id="adding-files-from-the-build-context"></a>
#### Adicionando arquivos do contexto de compilação

Qualquer caminho relativo ou local que não comece com um `http://`, `https://`, ou `git@` prefixo de protocolo é considerado um caminho de arquivo local. O caminho do arquivo local é relativo ao contexto de compilação. Por exemplo, se o contexto de compilação for o diretório atual, `ADD file.txt /` adiciona o arquivo em `./file.txt` para a raiz do sistema de arquivos no contêiner de compilação.

Especificar um caminho de origem com um slash líder ou um que navega fora do contexto de compilação, como `ADD ../something /something`, remove automaticamente qualquer navegação no diretório pai (`../`). Resfrias de trilha no caminho de origem também são desconsideradas, fazendo `ADD something/ /something` equivalente a `ADD something /something`.

Se a fonte for um diretório, o conteúdo do diretório será copiado, incluindo metadados do sistema de arquivos. O diretório em si não é copiado, apenas o seu conteúdo. Se ele contém subdiretórios, estes também são copiados e mesclados com quaisquer diretórios existentes no destino. Quaisquer conflitos são resolvidos em favor do conteúdo que está sendo adicionado, em uma base de arquivo por arquivo, exceto se você estiver tentando copiar um diretório em um arquivo existente, caso em que um erro é levantado.

Se a origem for um arquivo, o arquivo e seus metadados são copiados para o destino. As permissões de arquivo são preservadas. Se a fonte for um arquivo e um diretório com o mesmo nome existir no destino, um erro será levantado.

Se você passar um Dockerfile através de stdin para a construção (`docker build - < Dockerfile`), não há contexto de construção. Neste caso, você só pode usar o `ADD` instrução para copiar arquivos remotos. Você também pode passar um arquivo de alcatrão através de stdin: (`docker build - < archive.tar`), o Dockerfile na raiz do arquivo e o restante do arquivo serão usados como o contexto da compilação.

<a id="pattern-matching"></a>
##### Padrão matching

Para arquivos locais, cada um `<src>` pode conter curingas e correspondência será feita usando Go's [filepath.Match](https://golang.org/pkg/path/filepath#Match) regras.

Por exemplo, para adicionar todos os arquivos e diretórios na raiz do contexto de compilação que termina com `.png`:

```dockerfile
ADD *.png /dest/
```

No exemplo seguinte, `?` é um wildcard de caráter único, combinando por exemplo. `index.js` e `index.ts`.

```dockerfile
ADD index.?s /dest/
```

Ao adicionar arquivos ou diretórios que contenham caracteres especiais (como `[` e `]`), você precisa escapar desses caminhos seguindo as regras de Golang para evitar que eles sejam tratados como um padrão de correspondência. Por exemplo, para adicionar um arquivo nomeado `arr[0].txt`, utilizar o seguinte;

```dockerfile
ADD arr[[]0].txt /dest/
```

<a id="adding-local-tar-archives"></a>
#### Adicionando arquivos de alcarrão locais

Ao usar um arquivo de alcatrão local como fonte para `ADD`, e o arquivo está em um formato de compressão reconhecido (`gzip`, `bzip2` ou `xz`, ou não comprimido), o arquivo é descomprimido e extraído no destino especificado. Arquivos de alcatrão locais são extraídos por padrão, veja o [`ADD --unpack` bandeira].

Quando um diretório é extraído, ele tem o mesmo comportamento que `tar -x`. O resultado é a união de:

1. O que quer que existisse no caminho do destino, e
2. O conteúdo da árvore de origem, com conflitos resolvidos em favor do conteúdo que está sendo adicionado, em uma base de arquivo por arquivo.

> [!NOTE]
> Se um arquivo é identificado como um formato de compressão reconhecido ou não é feito exclusivamente com base no conteúdo do arquivo, não no nome do arquivo. Por exemplo, se um arquivo vazio terminar com `.tar.gz` isso não é reconhecido como um arquivo compactado e não gera nenhum tipo de mensagem de erro de descompressão, mas o arquivo será simplesmente copiado para o destino.

<a id="adding-files-from-a-url"></a>
#### Adicionando arquivos de uma URL

No caso em que a fonte é um URL de arquivo remoto, o destino terá permissões de 600. Se a resposta HTTP contém a `Last-Modified` cabeçalho, o carimpo de data/hora desse cabeçalho será usado para definir o `mtime` no arquivo de destino. No entanto, como qualquer outro arquivo processado durante um `ADD`, `mtime` não está incluído na determinação de se o arquivo mudou ou não e o cache deve ser atualizado.

Se o arquivo remoto for um arquivo tar, o arquivo não será extraído por padrão. Para baixar e extrair o arquivo, use o [`ADD --unpack` bandeira].

Se o destino terminar com uma barra de arrastamento, o nome do arquivo será inferido no caminho da URL. Por exemplo, `ADD http://example.com/foobar /` criaria o arquivo `/foobar`. A URL deve ter um caminho não trivial para que um nome de arquivo apropriado possa ser descoberto (`http://example.com` não funciona).

Se o destino não terminar com uma barra de arrastamento, o caminho de destino se tornará o nome do arquivo do arquivo baixado da URL. Por exemplo, `ADD http://example.com/foo /bar` cria o arquivo `/bar`.

Se seus arquivos de URL estiverem protegidos usando autenticação, você precisará usar `RUN wget`, `RUN curl` ou usar outra ferramenta de dentro do recipiente como o `ADD` instrução não suporta autenticação.

<a id="secrets"></a>
##### Segredos

Você pode usar o `HTTP_AUTH_HEADER_<host>` e `HTTP_AUTH_TOKEN_<host>` segredos para definir credenciais para fontes remotas. Para mais informações, consulte [Construir segredos](https://docs.docker.com/build/building/secrets/#http-authentication-for-add).

<a id="adding-files-from-a-git-repository"></a>
#### Adicionando arquivos de um repositório Git

Para usar um repositório Git como fonte para `ADD`, você pode referenciar o endereço HTTP ou SSH do repositório como a fonte. O repositório é clonado para o destino especificado na imagem.

```dockerfile
ADD https://github.com/user/repo.git /mydir/
```

Você pode usar fragmentos de URL para especificar uma ramificação, tag, commit ou subdiretório específico. Por exemplo, para adicionar o `docs` diretório do `v0.14.1` tag do `buildkit` repositório:

```dockerfile
ADD git@github.com:moby/buildkit.git#v0.14.1:docs /buildkit-docs
```

Para obter mais informações sobre fragmentos de URL do Git, consulte [Fregmentos de URL](https://docs.docker.com/build/building/context/#url-fragments).

Ao adicionar de um repositório Git, os bits de permissões para arquivos são 644. Se um arquivo no repositório tiver o bit executável definido, ele terá permissões definidas para 755. Os diretórios têm permissões definidas para 755.

Ao usar um repositório Git como fonte, o repositório deve estar acessível a partir do contexto de compilação. Para adicionar um repositório via SSH, seja público ou privado, você deve passar uma chave SSH para autenticação. Por exemplo, dado o seguinte Dockerfile:

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
ADD git@git.example.com:foo/bar.git /bar
```

Para construir este Dockerfile, passe o `--ssh` bandeira para o `docker build` para montar o soquete do agente SSH para a construção. Por exemplo:

```console
$ docker build --ssh default .
```

Para mais informações sobre a construção com segredos, consulte [Construir segredos](https://docs.docker.com/build/building/secrets/).

<a id="destination"></a>
### Destino

Se o caminho de destino começar com uma barra para a frente, ele é interpretado como um caminho absoluto e os arquivos de origem são copiados para o destino especificado em relação à raiz do estágio de compilação atual.

```dockerfile
# create /abs/test.txt
ADD test.txt /abs/
```

As barras de reboque são significativas. Por exemplo, `ADD test.txt /abs` cria um arquivo em `/abs`, enquanto `ADD test.txt /abs/` cria `/abs/test.txt`.

Se o caminho de destino não começar com um slash de liderança, ele é interpretado como relativo ao diretório de trabalho do contêiner de compilação.

```dockerfile
WORKDIR /usr/src/app
# create /usr/src/app/rel/test.txt
ADD test.txt rel/
```

Se o destino não existe, ele é criado, juntamente com todos os diretórios perdidos em seu caminho.

Se a fonte for um arquivo e o destino não terminar com uma barra, o arquivo de origem será gravado no caminho de destino como um arquivo.

<a id="add---keep-git-dir"></a>
### ADD --keep-git-dir

```dockerfile
ADD [--keep-git-dir=<boolean>] <src> ... <dir>
```

Quando `<src>` é o endereço HTTP ou SSH de um repositório Git remoto, o BuildKit adiciona o conteúdo do repositório Git à imagem, excluindo o `.git` diretório por padrão.

O `--keep-git-dir=true` bandeira permite preservar o `.git` diretório.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
ADD --keep-git-dir=true https://github.com/moby/buildkit.git#v0.10.1 /buildkit
```

<a id="add---checksum"></a>
### ADD --checksum

```dockerfile
ADD [--checksum=<hash>] <src> ... <dir>
```

O `--checksum` O flag permite que você verifique a soma de verificação de um recurso remoto do Git ou HTTP:

- Para fontes do Git, a soma de verificação é o commit SHA. Pode ser o commit completo SHA ou correspondência no prefixo (1 ou mais caracteres).
- Para fontes HTTP, a soma de verificação é o resumo de conteúdo SHA-256, formatado como `sha256:<hash>`. SHA-256 é o único algoritmo de hash suportado.

```dockerfile
ADD --checksum=be1f38e https://github.com/moby/buildkit.git#v0.26.2 /
ADD --checksum=sha256:24454f830cdb571e2c4ad15481119c43b3cafd48dd869a9b2945d1036d1dc68d https://mirrors.edge.kernel.org/pub/linux/kernel/Historic/linux-0.01.tar.gz /
```

<a id="add---chmod"></a>
### ADD --chmod

Ver [`COPY --chmod`](#copy---chmod).

<a id="add---chown"></a>
### ADD --chown

Ver [`COPY --chown`](#copy---chown).

<a id="add---link"></a>
### ADD --link

Ver [`COPY --link`](#copy---link).

<a id="add---unpack"></a>
### ADD --unpack

```dockerfile
ADD [--unpack=<bool>] <src> ... <dir>
```

O `--unpack` flag controla se deve ou não descompactar arquivos tar automaticamente (incluindo formatos comprimidos como `gzip` ou `bzip2`) ao adicioná-los à imagem. Os arquivos de alcatos locais são desempacotados por padrão, enquanto os arquivos de alcato remotos (onde `src` é um URL) são baixados sem desempacotar.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
# Download and unpack archive.tar.gz into /download:
ADD --unpack=true https://example.com/archive.tar.gz /download
# Add local tar without unpacking:
ADD --unpack=false my-archive.tar.gz .
```

<a id="add---exclude"></a>
### ADD --exclude

Ver [`COPY --exclude`](#copy---exclude).

<a id="copy"></a>
## COPY

COPY tem duas formas. Este último formulário é necessário para caminhos que contenham espaço em branco.

```dockerfile
COPY [OPTIONS] <src> ... <dest>
COPY [OPTIONS] ["<src>", ... "<dest>"]
```

O disponível `[OPTIONS]` são:

| Opção                             | Versão mínima do Dockerfile |
| ---------------------------------- | -------------------------- |
| [`--from`](#copy---from)           |                                                                                    |
| [`--chmod`](#copy---chmod)         |  1.2                                                |
| [`--chown`](#copy---chown)         |                                                                                    |
| [`--link`](#copy---link)           |  1.4                                                |
| [`--parents`](#copy---parents)     |  1.20                                              |
| [`--exclude`](#copy---exclude)     |  1.19                                              |

A instrução `COPY` copia novos arquivos ou diretórios de `<src>` e as adiciona ao sistema de arquivos da imagem no caminho `<dest>`. Arquivos e diretórios podem ser copiados do contexto de compilação, estágio de compilação, contexto nomeado ou uma imagem.

O `ADD` e `COPY` instruções são funcionalmente semelhantes, mas servem propósitos ligeiramente diferentes. Saiba mais sobre as [diferenças entre `ADD` e `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy).

<a id="source"></a>
### Fonte

Você pode especificar vários arquivos de origem ou diretórios com `COPY`. O último argumento deve ser sempre o destino. Por exemplo, para copiar dois arquivos, `file1.txt` e `file2.txt`, do contexto de construção para `/usr/src/things/` no recipiente de construção:

```dockerfile
COPY file1.txt file2.txt /usr/src/things/
```

Se você especificar vários arquivos de origem, diretamente ou usando um curinga, o destino deve ser um diretório (deve terminar com um slash `/`).

`COPY` aceita uma bandeira `--from=<name>` que permite especificar o local de origem para ser um estágio de compilação, contexto ou imagem. O exemplo a seguir copia arquivos de um estágio nomeado `build`:

```dockerfile
FROM golang AS build
WORKDIR /app
RUN --mount=type=bind,target=. go build -o /myapp ./cmd

COPY --from=build /myapp /usr/bin/
```

Para obter mais informações sobre a cópia de fontes nomeadas, consulte o [`--from` bandeira](#copy---from).

<a id="copying-from-the-build-context"></a>
#### Copiar a partir do contexto de compilação

Ao copiar arquivos de origem do contexto de compilação, os caminhos são interpretados como relativos à raiz do contexto.

Especificar um caminho de origem com um slash líder ou um que navega fora do contexto de compilação, como `COPY ../something /something`, remove automaticamente qualquer navegação no diretório pai (`../`). Resfrias de trilha no caminho de origem também são desconsideradas, fazendo `COPY something/ /something` equivalente a `COPY something /something`.

Se a fonte for um diretório, o conteúdo do diretório será copiado, incluindo metadados do sistema de arquivos. O diretório em si não é copiado, apenas o seu conteúdo. Se ele contém subdiretórios, estes também são copiados e mesclados com quaisquer diretórios existentes no destino. Quaisquer conflitos são resolvidos em favor do conteúdo que está sendo adicionado, em uma base de arquivo por arquivo, exceto se você estiver tentando copiar um diretório em um arquivo existente, caso em que um erro é levantado.

Se a origem for um arquivo, o arquivo e seus metadados são copiados para o destino. As permissões de arquivo são preservadas. Se a fonte for um arquivo e um diretório com o mesmo nome existir no destino, um erro será levantado.

Se você passar um Dockerfile através de stdin para a construção (`docker build - < Dockerfile`), não há contexto de construção. Neste caso, você só pode usar o `COPY` instrução para copiar arquivos de outros estágios, contextos nomeados ou imagens, usando o [`--from` bandeira](#copy---from). Você também pode passar um arquivo de alcatrão através de stdin: (`docker build - < archive.tar`), o Dockerfile na raiz do arquivo e o restante do arquivo serão usados como o contexto da compilação.

Ao usar um repositório Git como o contexto de compilação, os bits de permissões para arquivos copiados são 644. Se um arquivo no repositório tiver o bit executável definido, ele terá permissões definidas para 755. Os diretórios têm permissões definidas para 755.

<a id="pattern-matching"></a>
##### Padrão matching

Para arquivos locais, cada um `<src>` pode conter curingas e correspondência será feita usando Go's [filepath.Match](https://golang.org/pkg/path/filepath#Match) regras.

Por exemplo, para adicionar todos os arquivos e diretórios na raiz do contexto de compilação que termina com `.png`:

```dockerfile
COPY *.png /dest/
```

No exemplo seguinte, `?` é um wildcard de caráter único, combinando por exemplo. `index.js` e `index.ts`.

```dockerfile
COPY index.?s /dest/
```

Ao adicionar arquivos ou diretórios que contenham caracteres especiais (como `[` e `]`), você precisa escapar desses caminhos seguindo as regras de Golang para evitar que eles sejam tratados como um padrão de correspondência. Por exemplo, para adicionar um arquivo nomeado `arr[0].txt`, utilizar o seguinte;

```dockerfile
COPY arr[[]0].txt /dest/
```

<a id="destination"></a>
### Destino

Se o caminho de destino começar com uma barra para a frente, ele é interpretado como um caminho absoluto e os arquivos de origem são copiados para o destino especificado em relação à raiz do estágio de compilação atual.

```dockerfile
# create /abs/test.txt
COPY test.txt /abs/
```

As barras de reboque são significativas. Por exemplo, `COPY test.txt /abs` cria um arquivo em `/abs`, enquanto `COPY test.txt /abs/` cria `/abs/test.txt`.

Se o caminho de destino não começar com um slash de liderança, ele é interpretado como relativo ao diretório de trabalho do contêiner de compilação.

```dockerfile
WORKDIR /usr/src/app
# create /usr/src/app/rel/test.txt
COPY test.txt rel/
```

Se o destino não existe, ele é criado, juntamente com todos os diretórios perdidos em seu caminho.

Se a fonte for um arquivo e o destino não terminar com uma barra, o arquivo de origem será gravado no caminho de destino como um arquivo.

<a id="copy---from"></a>
### COPY --from

Por padrão, o `COPY` instruções copia arquivos do contexto de compilação. O `COPY --from` O sinalizador permite copiar arquivos de uma imagem, um estágio de compilação ou um contexto nomeado.

```dockerfile
COPY [--from=<image|stage|context>] <src> ... <dest>
```

Para copiar a partir de uma etapa de compilação em uma [construção de vários estágios](https://docs.docker.com/build/building/multi-stage/), especifique o nome do estágio do que você deseja copiar. Você especifica nomes de palco usando o `AS` palavra-chave com o `FROM` instrução.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine AS build
COPY . .
RUN apk add clang
RUN clang -o /hello hello.c

FROM scratch
COPY --from=build /hello /
```

Você também pode copiar arquivos diretamente de contextos nomeados (especificado com `--build-context <name>=<source>`) ou imagens. O exemplo a seguir copia um `nginx.conf` arquivo da imagem oficial de Nginx.

```dockerfile
COPY --from=nginx:latest /etc/nginx/nginx.conf /nginx.conf
```

O caminho de origem de `COPY --from` é sempre resolvido a partir da raiz do sistema de arquivos da imagem ou estágio que você especificar.

<a id="copy---chmod"></a>
### COPY --chmod

```dockerfile
COPY [--chmod=<perms>] <src> ... <dest>
```

O `--chmod` bandeira suporta notação octal (por exemplo, `755`, `644`) e notação simbólica (por exemplo, `+x`, `g=u`). A notação simbólica (adiciada no Dockerfile versão 1.14) é útil quando o octal não é flexível o suficiente. Por exemplo, `u=rwX,go=rX` define diretórios para 755 e arquivos para 644, enquanto preserva o bit executável em arquivos que já o têm. (Capital `X` significa "executável apenas se for um diretório ou já executável.")

Para obter mais informações sobre a sintaxe de notação simbólica, consulte o manual [chmod(1)](https://man.freebsd.org/cgi/man.cgi?chmod).

Exemplos usando a notação octal:

```dockerfile
COPY --chmod=755 app.sh /app/
COPY --chmod=644 file.txt /data/
ARG MODE=440
COPY --chmod=$MODE . .
```

Exemplos usando notação simbólica:

```dockerfile
COPY --chmod=+x script.sh /app/
COPY --chmod=u=rwX,go=rX . /app/
COPY --chmod=g=u config/ /config/
```

O `--chmod` bandeira não é suportado ao construir contêineres do Windows.

<a id="copy---chown"></a>
### COPY --chown

```dockerfile
COPY [--chown=<user>:<group>] <src> ... <dest>
```

Define a propriedade de arquivos copias. Sem essa bandeira, os arquivos são criados com UID e GID de 0.

O sinalizador aceita nomes de usuário, nomes de grupo, UIDs ou GIDs em qualquer combinação. Se você especificar apenas um usuário, o GID será definido como o mesmo valor numérico que o UID.

```dockerfile
COPY --chown=55:mygroup files* /somedir/
COPY --chown=bin files* /somedir/
COPY --chown=1 files* /somedir/
COPY --chown=10:11 files* /somedir/
COPY --chown=myuser:mygroup --chmod=644 files* /somedir/
```

Ao usar nomes em vez de IDs numéricos, o BuildKit os resolve usando `/etc/passwd` e `/etc/group` no sistema de arquivos raiz do contêiner. Se esses arquivos estiverem ausentes ou não contiverem os nomes especificados, a compilação falhará. Identificações numéricas não exigem essa pesquisa.

O `--chown` bandeira não é suportado ao construir contêineres do Windows.

<a id="copy---link"></a>
### COPY --link

```dockerfile
COPY [--link[=<boolean>]] <src> ... <dest>
```

Possibiliotar esta bandeira em `COPY` ou `ADD` comandos permite copiar arquivos com semântica aprimorada onde seus arquivos permanecem independentes em sua própria camada e não são invalidados quando comandos em camadas anteriores são alterados.

Quando `--link` é usado seus arquivos de origem são copiados para um diretório de destino vazio. Esse diretório é transformado em uma camada que está vinculada em cima do seu estado anterior.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
COPY --link /foo /bar
```

É equivalente a fazer duas construções:

```dockerfile
FROM alpine
```

e

```dockerfile
FROM scratch
COPY /foo /bar
```

e mescamendo todas as camadas de ambas as imagens juntas.

<a id="benefits-of-using---link"></a>
#### Benefícios do uso `--link`

Uso `--link` para reutilizar camadas já construídas em compilações subsequentes com `--cache-from` mesmo que as camadas anteriores tenham mudado. Isso é especialmente importante para construções em vários estágios em que a `COPY --from` declaração anteriormente seria invalidada se quaisquer comandos anteriores no mesmo estágio fossem alterados, fazendo com que a necessidade de reconstruir os estágios intermediários novamente. Com `--link` a camada que a compilação anterior gerou é reutilizada e mesclada em cima das novas camadas. Isso também significa que você pode facilmente rebasear suas imagens quando as imagens base recebem atualizações, sem ter que executar toda a compilação novamente. Em backends que suportam, o BuildKit pode fazer essa ação de rebase sem a necessidade de empurrar ou puxar quaisquer camadas entre o cliente e o registro. O BuildKit detectará este caso e criará apenas um novo manifesto de imagem que contenha as novas camadas e as camadas antigas em ordem correta.

O mesmo comportamento em que o BuildKit pode evitar puxar a imagem base também pode acontecer ao usar `--link` e nenhum outro comando que exigiria acesso aos arquivos na imagem base. Nesse caso, o BuildKit só construirá as camadas para o `COPY` comandos e empurrá-los para o registro diretamente em cima das camadas da imagem base.

<a id="incompatibilities-with---linkfalse"></a>
#### Incompatibilidades com `--link=false`

Ao usar `--link` o `COPY/ADD` comandos não são permitidos ler quaisquer arquivos do estado anterior. Isso significa que, se no estado anterior, o diretório de destino era um caminho que continha um link simbólico, `COPY/ADD` não pode segui-lo. Na imagem final o caminho de destino criado com `--link` será sempre um caminho contendo apenas diretórios.

Se você não confiar no comportamento de seguir links simbólicos no caminho de destino, usando `--link` é sempre recomendado. O desempenho de `--link` é equivalente ou melhor do que o comportamento padrão e, cria condições muito melhores para a reutilização de cache.

Ao copiar um caminho para um subdiretório, `--link` sempre copiará da raiz do sistema de arquivos. Ao copiar um diretório, o modo existente é substituído pelo novo modo a partir do caminho copiado. Se você precisa de um modo específico para um diretório, como o mais permissivo `/tmp` diretório, você pode precisar evitar usar `--link`, desenrolar a cópia em seus componentes de base, ou usar `--chmod` para garantir que o diretório de sobrescrita contenha as mesmas permissões.

<a id="copy---parents"></a>
### COPY --parents

```dockerfile
COPY [--parents[=<boolean>]] <src> ... <dest>
```

O `--parents` bandeira preserva diretórios de pais para `src` entradas. Este sinalizador é padrão para `false`.

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch

COPY ./x/a.txt ./y/a.txt /no_parents/
COPY --parents ./x/a.txt ./y/a.txt /parents/

# /no_parents/a.txt
# /parents/x/a.txt
# /parents/y/a.txt
```

Este comportamento é semelhante ao [Linux `cp` utilitário's](https://www.man7.org/linux/man-pages/man1/cp.1.html) `--parents` ou [`rsync`](https://man7.org/linux/man-pages/man1/rsync.1.html) `--relative` bandeira.

Tal como acontece com Rsync, é possível limitar quais diretórios pais são preservados através da inserção de um ponto e um slash (`./`) no caminho de origem. Se tal ponto existir, apenas os diretórios de pais depois de serem preservados. Isso pode ser especialmente útil cópias entre os estágios com `--from` onde os caminhos de origem precisam ser absolutos.

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch

COPY --parents ./x/./y/*.txt /parents/

# Build context:
# ./x/y/a.txt
# ./x/y/b.txt
#
# Output:
# /parents/y/a.txt
# /parents/y/b.txt
```

O `**` wildcard corresponde a qualquer número de componentes de caminho, incluindo nenhum, e pode ser usado para corresponder recursivamente arquivos em níveis de diretório:

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch

COPY --parents ./src/**/*.txt /parents/

# Build context:
# ./src/a.txt
# ./src/x/b.txt
# ./src/x/y/c.txt
#
# Output:
# /parents/src/a.txt
# /parents/src/x/b.txt
# /parents/src/x/y/c.txt
```

Note que, sem o `--parents` bandeira especificada, qualquer colisão de nome de arquivo irá falhar o Linux `cp` operação com uma mensagem de erro explícita (`cp: will not overwrite just-created './x/a.txt' with './y/a.txt'`), onde o Buildkit irá silenciosamente sobrescrever o arquivo de destino no destino.

Embora seja possível preservar a estrutura de diretórios para `COPY` instruções que consistem em apenas uma `src` entrada, geralmente é mais benéfico manter a contagem de camadas na imagem resultante o mais baixo possível. Portanto, com o `--parents` bandeira, o Buildkit é capaz de embalar múltiplos `COPY` instruções em conjunto, mantendo a estrutura de diretórios intacta.

<a id="copy---exclude"></a>
### COPY --exclude

```dockerfile
COPY [--exclude=<path> ...] <src> ... <dest>
```

O `--exclude` O sinal de ordem permite que você especifique uma expressão de caminho para que os arquivos sejam excluídos.

A expressão do caminho segue o mesmo formato que `<src>`, suportando curingas e combinando usando o [filepath.Match do Go](https://golang.org/pkg/path/filepath#Match) regras. Por exemplo, para adicionar todos os arquivos começando com "hom", excluindo arquivos com um `.txt` extensão:

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch

COPY --exclude=*.txt hom* /mydir/
```

Você pode especificar o `--exclude` opção várias vezes para a `COPY` instrução. Arquivos correspondentes a qualquer um dos especificados `--exclude` padrões não são copiados, mesmo que seus caminhos correspondam ao padrão especificado em `<src>`. Para adicionar todos os arquivos que começam com "hom", excluindo arquivos com qualquer um `.txt` ou `.md` extensões:

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch

COPY --exclude=*.txt --exclude=*.md hom* /mydir/
```

<a id="entrypoint"></a>
## ENTRYPOINT

Um `ENTRYPOINT` permite configurar um container que será executado como um exputo.

`ENTRYPOINT` tem duas formas possíveis:

- A forma executiva, que é a forma preferida:

  ```dockerfile
  ENTRYPOINT ["executable", "param1", "param2"]
  ```

- A forma da casca:

  ```dockerfile
  ENTRYPOINT command param1 param2
  ```

Para obter mais informações sobre os diferentes formulários, consulte [Formulária e formulário executivo](#shell-and-exec-form).

O seguinte comando inicia um container a partir do `nginx` com seu conteúdo padrão, ouvindo na porta 80:

```console
$ docker run -i -t --rm -p 80:80 nginx
```

Argumentos de linha de comando para `docker run <image>` será anexado após todos os elementos em uma forma executiva `ENTRYPOINT`, e substituirá todos os elementos especificados usando `CMD`.

Isso permite que argumentos sejam passados para o ponto de entrada, ou seja, `docker run <image> -d` vai passar o `-d` argumento ao ponto de entrada. Você pode anular o `ENTRYPOINT` instrução usando o `docker run --entrypoint` bandeira.

A forma de casca de `ENTRYPOINT` ignora qualquer `CMD` ou `docker run` argumentos de linha de comando. Também começa o seu `ENTRYPOINT` como um subcomando de `/bin/sh -c`, que não passa sinais. Isso significa que o executável não será do contêiner `PID 1`, e não receberá sinais Unix. Neste caso, o seu executável não recebe a `SIGTERM` de `docker stop <container>`.

Apenas o último `ENTRYPOINT` instrução no Dockerfile terá um efeito.

<a id="exec-form-entrypoint-example"></a>
### Forma exec ENTRYPOINT exemplo

Você pode usar a forma executiva de `ENTRYPOINT` para definir comandos e argumentos padrão bastante estáveis e, em seguida, usar `CMD` para definir padrões adicionais que são mais propensos a serem alterados.

Ao combinar a forma executiva `ENTRYPOINT` com `CMD`, utilizar a forma executiva de `CMD` também. Usando a forma de shell de `CMD` faz com que seja envolto em `/bin/sh -c`, que significa o `ENTRYPOINT` recebe uma invocação de shell como seu argumento em vez do comando e parâmetros nus. Veja [Entenda como CMD e ENTRYPOINT interagir](#understand-how-cmd-and-entrypoint-interact).

```dockerfile
FROM ubuntu
ENTRYPOINT ["top", "-b"]
CMD ["-c"]
```

Quando você executa o recipiente, você pode ver isso `top` é o único processo:

```console
$ docker run -it --rm --name test  top -H

top - 08:25:00 up  7:27,  0 users,  load average: 0.00, 0.01, 0.05
Threads:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.1 us,  0.1 sy,  0.0 ni, 99.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem:   2056668 total,  1616832 used,   439836 free,    99352 buffers
KiB Swap:  1441840 total,        0 used,  1441840 free.  1324440 cached Mem

  PID USER      PR  NI    VIRT    RES    SHR S %CPU %MEM     TIME+ COMMAND
    1 root      20   0   19744   2336   2080 R  0.0  0.1   0:00.04 top
```

Para examinar o resultado mais adiante, você pode usar `docker exec`:

```console
$ docker exec -it test ps aux

USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  2.6  0.1  19752  2352 ?        Ss+  08:24   0:00 top -b -H
root         7  0.0  0.1  15572  2164 ?        R+   08:25   0:00 ps aux
```

E você pode pedir graciosamente `top` para desligar usando `docker stop test`.

O seguinte Dockerfile mostra usando o `ENTRYPOINT` para executar o Apache em primeiro plano (ou seja, como `PID 1`):

```dockerfile
FROM debian:stable
RUN apt-get update && apt-get install -y --force-yes apache2
EXPOSE 80 443
VOLUME ["/var/www", "/var/log/apache2", "/etc/apache2"]
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
```

Se você precisar escrever um script inicial para um único executável, poderá garantir que o executável final receba os sinais Unix usando `exec` e `gosu` comandos:

```bash
#!/usr/bin/env bash
set -e

if [ "$1" = 'postgres' ]; then
    chown -R postgres "$PGDATA"

    if [ -z "$(ls -A "$PGDATA")" ]; then
        gosu postgres initdb
    fi

    exec gosu postgres "$@"
fi

exec "$@"
```

Por último, se você precisa fazer alguma limpeza extra (ou se comunicar com outros contêineres) no desligamento, ou estiver coordenando mais de um executável, talvez seja necessário garantir que o `ENTRYPOINT` script recebe os sinais Unix, os passa e depois faz mais algum trabalho:

```bash
#!/bin/sh
# Note: I've written this using sh so it works in the busybox container too

# USE the trap if you need to also do manual cleanup after the service is stopped,
#     or need to start multiple services in the one container
trap "echo TRAPed signal" HUP INT QUIT TERM

# start service in background here
/usr/sbin/apachectl start

echo "[hit enter key to exit] or run 'docker stop <container>'"
read

# stop service and clean up here
echo "stopping apache"
/usr/sbin/apachectl stop

echo "exited $0"
```

Se você executar esta imagem com `docker run -it --rm -p 80:80 --name test apache`, você pode então examinar os processos do contêiner com `docker exec`, ou `docker top`, e depois peça ao script para parar o Apache:

```console
$ docker exec -it test ps aux

USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.1  0.0   4448   692 ?        Ss+  00:42   0:00 /bin/sh /run.sh 123 cmd cmd2
root        19  0.0  0.2  71304  4440 ?        Ss   00:42   0:00 /usr/sbin/apache2 -k start
www-data    20  0.2  0.2 360468  6004 ?        Sl   00:42   0:00 /usr/sbin/apache2 -k start
www-data    21  0.2  0.2 360468  6000 ?        Sl   00:42   0:00 /usr/sbin/apache2 -k start
root        81  0.0  0.1  15572  2140 ?        R+   00:44   0:00 ps aux

$ docker top test

PID                 USER                COMMAND
10035               root                {run.sh} /bin/sh /run.sh 123 cmd cmd2
10054               root                /usr/sbin/apache2 -k start
10055               33                  /usr/sbin/apache2 -k start
10056               33                  /usr/sbin/apache2 -k start

$ /usr/bin/time docker stop test

test
real	0m 0.27s
user	0m 0.03s
sys	0m 0.03s
```

> [!NOTE]
> Você pode anular o `ENTRYPOINT` configuração usando `--entrypoint`, mas isso só pode definir o binário para exec (no `sh -c` será utilizado).

<a id="shell-form-entrypoint-example"></a>
### Forma shell ENTRYPOINT exemplo

Você pode especificar uma string simples para o `ENTRYPOINT` e ele será executado em `/bin/sh -c`. Este formulário usará o processamento de shell para substituir variáveis de ambiente shell e ignorará qualquer `CMD` ou `docker run` argumentos de linha de comando. Para garantir que `docker stop` sinalizará qualquer corrida longa `ENTRYPOINT` executável corretamente, você precisa lembrar de iniciá-lo com `exec`:

```dockerfile
FROM ubuntu
ENTRYPOINT exec top -b
```

Quando você executar esta imagem, você verá o single `PID 1` processo:

```console
$ docker run -it --rm --name test top

Mem: 1704520K used, 352148K free, 0K shrd, 0K buff, 140368121167873K cached
CPU:   5% usr   0% sys   0% nic  94% idle   0% io   0% irq   0% sirq
Load average: 0.08 0.03 0.05 2/98 6
  PID  PPID USER     STAT   VSZ %VSZ %CPU COMMAND
    1     0 root     R     3164   0%   0% top -b
```

Qual sai de forma limpa `docker stop`:

```console
$ /usr/bin/time docker stop test

test
real	0m 0.20s
user	0m 0.02s
sys	0m 0.04s
```

Caso se esqueça de adicionar `exec` ao início do seu `ENTRYPOINT`:

```dockerfile
FROM ubuntu
ENTRYPOINT top -b
CMD -- --ignored-param1
```

Você pode então exemurá-lo (dando-lhe um nome para o próximo passo):

```console
$ docker run -it --name test top --ignored-param2

top - 13:58:24 up 17 min,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   2 total,   1 running,   1 sleeping,   0 stopped,   0 zombie
%Cpu(s): 16.7 us, 33.3 sy,  0.0 ni, 50.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   1990.8 total,   1354.6 free,    231.4 used,    404.7 buff/cache
MiB Swap:   1024.0 total,   1024.0 free,      0.0 used.   1639.8 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
    1 root      20   0    2612    604    536 S   0.0   0.0   0:00.02 sh
    6 root      20   0    5956   3188   2768 R   0.0   0.2   0:00.00 top
```

Você pode ver a partir da saída de `top` que o especificado `ENTRYPOINT` não é `PID 1`.

Se você então correr `docker stop test`, o recipiente não sairá de forma limpa - o comando `stop` será forçado a enviar uma `SIGKILL` após o tempo limite:

```console
$ docker exec -it test ps waux

USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.4  0.0   2612   604 pts/0    Ss+  13:58   0:00 /bin/sh -c top -b --ignored-param2
root         6  0.0  0.1   5956  3188 pts/0    S+   13:58   0:00 top -b
root         7  0.0  0.1   5884  2816 pts/1    Rs+  13:58   0:00 ps waux

$ /usr/bin/time docker stop test

test
real	0m 10.19s
user	0m 0.04s
sys	0m 0.03s
```

<a id="understand-how-cmd-and-entrypoint-interact"></a>
### Entenda como CMD e ENTRYPOINT interagir

Ambos `CMD` e `ENTRYPOINT` instruções definem qual comando é executado ao executar um contêiner. São poucas as regras que descrevem a sua cooperação.

1. Dockerfile deve especificar pelo menos um de `CMD` ou `ENTRYPOINT` comandos.

2. `ENTRYPOINT` deve ser definido ao usar o contêiner como um executável.

3. `CMD` deve ser usado como uma forma de definir argumentos padrão para um `ENTRYPOINT` comando ou para executar um comando ad-hoc em um contêiner.

4. `CMD` será substituído ao executar o contêiner com argumentos alternativos.

A tabela abaixo mostra qual comando é executado para diferentes `ENTRYPOINT` / `CMD` combinações:

|                                                                                                | Não ENTRYPOINT              | ENTRYPOINT exec_entry p1_entry | ENTRYPOINT ["exec_entry", "p1_entry"]          |
| :----------------------------- | :------------------------- | :----------------------------- | :--------------------------------------------- |
| **Não CMD**                     | erro, não permitido         | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry                            |
| **CMD ["exec_cmd", "p1_cmd"]** | exec_cmd p1_cmd            | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry exec_cmd p1_cmd            |
| **CMD exec_cmd p1_cmd**        | /bin/sh -c exec_cmd p1_cmd | /bin/sh -c exec_entry p1_entry | exec_entry p1_entry /bin/sh -c exec_cmd p1_cmd |

> [!NOTE]
> Se `CMD` é definida a partir da imagem base, configuração `ENTRYPOINT` irá redefinir `CMD` a um valor vazio. Neste cenário, `CMD` deve ser definido na imagem atual para ter um valor.

<a id="volume"></a>
## VOLUME

```dockerfile
VOLUME ["/data"]
```

O `VOLUME` A instrução cria um ponto de montagem com o nome especificado e marca-o como segurando volumes montados externamente a partir de host nativo ou outros contêineres. O valor pode ser uma matriz JSON, `VOLUME ["/var/log/"]`, ou uma string simples com múltiplos argumentos, como `VOLUME /var/log` ou `VOLUME /var/log /var/db`. Para obter mais informações/exemplos e instruções de montagem através do cliente Docker, consulte [_Share Directorys via Volumes_](https://docs.docker.com/storage/volumes/) documentação.

O `docker run` comando inicializa o volume recém-criado com quaisquer dados que existam no local especificado dentro da imagem base. Por exemplo, considere o seguinte trecho do Dockerfile:

```dockerfile
FROM ubuntu
RUN mkdir /myvol
RUN echo "hello world" > /myvol/greeting
VOLUME /myvol
```

Este Dockerfile resulta em uma imagem que causa `docker run` para criar um novo ponto de montagem em `/myvol` e copiar o `greeting` arquivo no volume recém-criado.

<a id="notes-about-specifying-volumes"></a>
### Notas sobre a especificação de volumes

Tenha em mente as seguintes coisas sobre os volumes no Dockerfile.

- **Volumes em contêineres baseados no Windows**: Ao usar contêineres baseados no Windows, o destino de um volume dentro do contêiner deve ser um dos:

  - um diretório não existente ou vazio
  - um drive diferente de `C:`

- **Alterando o volume de dentro do Dockerfile**: Se alguma etapa de compilação alterar os dados dentro do volume após ter sido declarado, essas alterações serão descartadas ao usar o construtor legado. Ao usar o Buildkit, as alterações serão mantidas.

- **JSON formatação**: A lista é analisada como uma matriz JSON. Você deve incluir palavras com citações duplas (`"`) em vez de citações únicas (`'`).

- **O diretório host é declarado em tempo de execução do contêiner**: O diretório host (o ponto de montagem) é, por sua natureza, dependente do host. Isso é para preservar a portabilidade da imagem, uma vez que um determinado diretório host não pode estar disponível em todos os hosts. Por esse motivo, você não pode montar um diretório host de dentro do Dockerfile. A instrução `VOLUME` não suporta especificar a `host-dir` parâmetro. Você deve especificar o ponto de montagem quando criar ou executar o contêiner.

<a id="user"></a>
## USER

```dockerfile
USER <user>[:<group>]
```

ou

```dockerfile
USER <UID>[:<GID>]
```

O `USER` A instrução define o nome de usuário (ou UID) e, opcionalmente, o grupo de usuário (ou GID) para usar como usuário e grupo padrão para o restante do estágio atual. O usuário especificado é usado para `RUN` instruções e em tempo de execução executa o relevante `ENTRYPOINT` e `CMD` comandos.

> Observe que, ao especificar um grupo para o usuário, o usuário terá _apenas_ a associação de grupo especificada. Quaisquer outras associações de grupo configuradas serão ignoradas.

> [!WARNING]
> Quando o usuário não tiver um grupo primário, a imagem (ou as próximas instruções) será executada com o `root` grupo.
>
> No Windows, o usuário deve ser criado primeiro se não for uma conta integrada. Isso pode ser feito com o comando `net user` chamado como parte de um Dockerfile.

```dockerfile
FROM microsoft/windowsservercore
# Create Windows user in the container
RUN net user /add patrick
# Set it for subsequent commands
USER patrick
```

<a id="workdir"></a>
## WORKDIR

```dockerfile
WORKDIR /path/to/workdir
```

A instrução `WORKDIR` define o diretório de trabalho para qualquer `RUN`, `CMD`, `ENTRYPOINT`, `COPY` e `ADD` instruções que o seguem no Dockerfile. Se o `WORKDIR` não existe, ele será criado mesmo que não seja usado em nenhuma instrução Dockerfile subsequente.

A instrução `WORKDIR` pode ser usado várias vezes em um Dockerfile. Se um caminho relativo for fornecido, ele será relativo ao caminho do anterior `WORKDIR` instrução. Por exemplo:

```dockerfile
WORKDIR /a
WORKDIR b
WORKDIR c
RUN pwd
```

A saída da final `pwd` comando neste Dockerfile seria `/a/b/c`.

A instrução `WORKDIR` pode resolver variáveis de ambiente previamente definidas usando `ENV`. Você só pode usar variáveis de ambiente explicitamente definidas no Dockerfile. Por exemplo:

```dockerfile
ENV DIRPATH=/path
WORKDIR $DIRPATH/$DIRNAME
RUN pwd
```

A saída da final `pwd` comando neste Dockerfile seria `/path/$DIRNAME`

Se não for especificado, o diretório de trabalho padrão é `/`. Na prática, se você não está construindo um Dockerfile a partir do zero (`FROM scratch`), o `WORKDIR` provavelmente pode ser definido pela imagem base que você está usando.

Portanto, para evitar operações não intencionais em diretórios desconhecidos, é melhor prática definir o seu `WORKDIR` explicitamente.

<a id="arg"></a>
## ARG

```dockerfile
ARG <name>[=<default value>] [<name>[=<default value>]...]
```

A instrução `ARG` define uma variável que os usuários podem passar no tempo de compilação para o construtor com o comando `docker build` usando o `--build-arg <varname>=<value>` bandeira. Esta variável pode ser usada em instruções posteriores, tais como `FROM`, `ENV`, `WORKDIR`, e outros usando o `${VAR}` ou `$VAR` sintaxe de modelo. Também é passado para todos os subsequentes `RUN` instruções como uma variável de ambiente de tempo de construção.

Diferentemente `ENV`, um `ARG` variável não está incorporada na imagem e não está disponível no recipiente final.

> [!WARNING]
> Não é recomendado usar argumentos de compilação para a passagem de segredos, como credenciais de usuário, tokens de API, etc. Argumentos de compilação são visíveis no `docker history` comando e em `max` atestados de proveniência de modo, que são anexados à imagem por padrão se você usar o Buildx GitHub Actions e seu repositório do GitHub for público.
>
> Referem-se ao [`RUN --mount=type=secret`](#run---mounttypesecret) seção para aprender sobre maneiras seguras de usar segredos ao construir imagens.

Um Dockerfile pode incluir um ou mais `ARG` instruções. Por exemplo, o seguinte é um Dockerfile válido:

```dockerfile
FROM busybox
ARG user1
ARG buildno
# ...
```

<a id="default-values"></a>
### Valores padrão

Um `ARG` A instrução pode, opcionalmente, incluir um valor padrão:

```dockerfile
FROM busybox
ARG user1=someuser
ARG buildno=1
# ...
```

Se uma instrução `ARG` tem um valor padrão e se não houver nenhum valor passado no tempo de compilação, o construtor usa o padrão.

<a id="scope"></a>
### Âmbito

Um `ARG` variável entra em vigor a partir da linha em que é declarada no Dockerfile. Por exemplo, considere este Dockerfile:

```dockerfile
FROM busybox
USER ${username:-some_user}
ARG username
USER $username
# ...
```

Um usuário cria esse arquivo chamando:

```console
$ docker build --build-arg username=what_user .
```

- A instrução `USER` na linha 2 avalia para o `some_user` fallback, porque o `username` variável ainda não é declarada.
- O `username` variável é declarada na linha 3, e disponível para referência na instrução Dockerfile a partir desse ponto em diante.
- A instrução `USER` na linha 4 avalia para `what_user`, já que nesse ponto o `username` argumento tem um valor de `what_user` que foi passado na linha de comando. Antes de sua definição por uma instrução `ARG`, qualquer uso de uma variável resulta em uma string vazia.

Um `ARG` variável declarada dentro de um estágio de compilação é automaticamente herdada por outros estágios com base nesse estágio. Os estágios de compilação não relacionados não têm acesso à variável. Para usar um argumento em vários estágios distintos, cada etapa deve incluir o `ARG` instrução, ou ambos devem ser baseados em um estágio base compartilhado no mesmo Dockerfile onde a variável é declarada.

Para mais informações, consulte [escopamento variável](https://docs.docker.com/build/building/variables/#scoping).

<a id="using-arg-variables"></a>
### Usando ARG variáveis

Você pode usar um `ARG` ou uma instrução `ENV` para especificar variáveis que estão disponíveis para o `RUN` instrução. Variáveis de ambiente definidas usando o `ENV` instrução sempre sobrepor uma instrução `ARG` do mesmo nome. Considere este Dockerfile com um `ENV` e `ARG` instrução.

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
ENV CONT_IMG_VER=v1.0.0
RUN echo $CONT_IMG_VER
```

Então, assuma que esta imagem é construída com este comando:

```console
$ docker build --build-arg CONT_IMG_VER=v2.0.1 .
```

Neste caso, o `RUN` instruções utiliza `v1.0.0` em vez do `ARG` configuração passada pelo usuário:`v2.0.1` Esse comportamento é semelhante a um script shell onde uma variável de escopo local substitui as variáveis passadas como argumentos ou herdadas do ambiente, do seu ponto de definição.

Usando o exemplo acima, mas um diferente `ENV` especificação você pode criar interações mais úteis entre `ARG` e `ENV` instruções:

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
ENV CONT_IMG_VER=${CONT_IMG_VER:-v1.0.0}
RUN echo $CONT_IMG_VER
```

Diferente de uma instrução `ARG`, `ENV` valores são sempre persistidos na imagem construída. Considere uma construção de docker sem o `--build-arg` bandeira:

```console
$ docker build .
```

Usando este exemplo do Dockerfile, `CONT_IMG_VER` ainda persiste na imagem mas seu valor seria `v1.0.0` como é o padrão definido na linha 3 pelo `ENV` instrução.

A técnica de expansão de variáveis neste exemplo permite que você passe argumentos da linha de comando e persista-os na imagem final, aproveitando o `ENV` instrução. A expansão variável é suportada apenas para [um conjunto limitado de instruções do Dockerfile.](#environment-replacement)

<a id="predefined-args"></a>
### ARGs predefinidos

Docker tem um conjunto de predefinidos `ARG` variáveis que você pode usar sem um correspondente `ARG` instrução no Dockerfile.

- `HTTP_PROXY`
- `http_proxy`
- `HTTPS_PROXY`
- `https_proxy`
- `FTP_PROXY`
- `ftp_proxy`
- `NO_PROXY`
- `no_proxy`
- `ALL_PROXY`
- `all_proxy`

Para usá-los, passe-os na linha de comando usando o `--build-arg` bandeira, por exemplo:

```console
$ docker build --build-arg HTTPS_PROXY=https://my-proxy.example.com .
```

Por padrão, essas variáveis pré-definidas são excluídas da saída de `docker history`. Exclui-los reduz o risco de vazar acidentalmente informações de autenticação confidenciais em um `HTTP_PROXY` variável.

Por exemplo, considere a construção do seguinte Dockerfile usando `--build-arg HTTP_PROXY=http://user:pass@proxy.lon.example.com`

```dockerfile
FROM ubuntu
RUN echo "Hello World"
```

Neste caso, o valor do `HTTP_PROXY` variável não está disponível no `docker history` e não está em cache. Se você fosse alterar o local, e seu servidor proxy fosse alterado para `http://user:pass@proxy.sfo.example.com`, uma compilação subsequente não resulta em uma falha de cache.

Se você precisa substituir esse comportamento, então você pode fazê-lo adicionando um `ARG` declaração no Dockerfile da seguinte forma:

```dockerfile
FROM ubuntu
ARG HTTP_PROXY
RUN echo "Hello World"
```

Ao construir este Dockerfile, o `HTTP_PROXY` é preservado no `docker history`, e alterar seu valor invalida o cache de compilação.

<a id="automatic-platform-args-in-the-global-scope"></a>
### Plataforma automática ARGs no âmbito global

Esse recurso só está disponível ao usar o [BuildKit](https://docs.docker.com/build/buildkit/) backend.

O BuildKit suporta um conjunto predefinido de `ARG` variáveis com informações sobre a plataforma do nó que executa a compilação (plataforma de compilação) e na plataforma da imagem resultante (plataforma alvo). A plataforma de destino pode ser especificada com o `--platform` bandeira em `docker build`.

O seguinte `ARG` variáveis são definidas automaticamente:

- `TARGETPLATFORM` - plataforma do resultado de compilação. Eg `linux/amd64`, `linux/arm/v7`, `windows/amd64`.
- `TARGETOS` - ComponentE do sistema operacional de TARGETPLATFORM
- `TARGETARCH` - componente de arquitetura da TARGETPLATFORM
- `TARGETVARIANT` - componente variante da TARGETPLATFORM
- `BUILDPLATFORM` - plataforma do nó realizando a compilação.
- `BUILDOS` - ComponentE de sistema operacional da BUILDPLATFORM
- `BUILDARCH` - componente de arquitetura da BUILDPLATFORM
- `BUILDVARIANT` - componente variante da BUILDPLATFORM

Esses argumentos são definidos no escopo global, portanto, não estão disponíveis automaticamente dentro dos estágios de compilação ou para o seu `RUN` comandos. Para expor um desses argumentos dentro do estágio de construção redefini-lo sem valor.

Por exemplo:

```dockerfile
FROM alpine
ARG TARGETPLATFORM
RUN echo "I'm building for $TARGETPLATFORM"
```

<a id="buildkit-built-in-build-args"></a>
### BuildKit built-in construir args

| Arg                             | Tipo   | Descrição                                                                                                                                                                                                      |
|---------------------------------|--------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `BUILDKIT_BUILD_NAME`           | Cordas | Substituir o nome de compilação mostrado em [`buildx history` comando](https://docs.docker.com/reference/cli/docker/buildx/history/) e [Docker Desktop Builds view](https://docs.docker.com/desktop/use-desktop/builds/). |
| `BUILDKIT_CACHE_MOUNT_NS`       | Cordas | Definir espaço de identificação de cache opcional.                                                                                                                                                                                 |
| `BUILDKIT_CONTEXT_KEEP_GIT_DIR` | Bool   | Acionar o contexto do Git para manter o `.git` diretório.                                                                                                                                                                |
| `BUILDKIT_INLINE_CACHE`[^2]     | Bool   | Metadados de cache em linha para configuração de imagem ou não.                                                                                                                                                                    |
| `BUILDKIT_MULTI_PLATFORM`       | Bool   | Opte pela saída determinística independentemente da saída multiplataforma ou não.                                                                                                                                        |
| `BUILDKIT_SANDBOX_HOSTNAME`     | Cordas | Definir o nome do host (padrão `buildkitsandbox`)                                                                                                                                                                     |
| `BUILDKIT_SYNTAX`               | Cordas | Definir imagem frontend. Definir para `dockerfile.v0` para ignorar o Dockerfile `# syntax=` diretiva e usar o frontend embutido em vez disso.                                                                                 |
| `SOURCE_DATE_EPOCH`             | Int    | Defina o carimpo de data/hora Unix para imagens e camadas criadas. Mais informações de [construções reprodutíveis](https://reproducible-builds.org/docs/source-date-epoch/). Suportado desde Dockerfile 1.5, BuildKit 0.11                |

<a id="example-keep-git-dir"></a>
#### Exemplo: manter `.git` dir

Ao usar um contexto Git, `.git` Dir não é mantido em checkouts. Pode ser útil mantê-lo por perto se você quiser recuperar informações git durante a sua compilação:

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
WORKDIR /src
RUN --mount=target=. \
  make REVISION=$(git rev-parse HEAD) build
```

```console
$ docker build --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=1 https://github.com/user/repo.git#main
```

<a id="impact-on-build-caching"></a>
### Impacto no cache de construção

`ARG` variáveis não são persistidas na imagem construída como `ENV` variáveis são. No entanto, `ARG` variáveis impactam o cache de compilação de maneiras semelhantes. Se um Dockerfile define um `ARG` variável cujo valor é diferente de uma compilação anterior, então uma "cache miss" ocorre após seu primeiro uso, não sua definição. Em particular, todos `RUN` instruções seguindo uma `ARG` instrução usar o `ARG` variável implicitamente (como uma variável de ambiente), assim pode causar uma falha de cache. Tudo pré-definido `ARG` variáveis estão isentas de cache, a menos que haja uma correspondência `ARG` declaração no Dockerfile.

Por exemplo, considere estes dois Dockerfile:

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
RUN echo $CONT_IMG_VER
```

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
RUN echo hello
```

Se você especificar `--build-arg CONT_IMG_VER=<value>` na linha de comando, em ambos os casos, a especificação na linha 2 não causa um cache miss; a linha 3 causa uma falha de cache. `ARG CONT_IMG_VER` causa a `RUN` linha a ser identificada como a mesma que correr `CONT_IMG_VER=<value> echo hello`, então se o `<value>` mudanças, você recebe uma falha de cache.

Considere outro exemplo sob a mesma linha de comando:

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
ENV CONT_IMG_VER=$CONT_IMG_VER
RUN echo $CONT_IMG_VER
```

Neste exemplo, a falha do cache ocorre na linha 3. A falta acontece porque o valor da variável no `ENV` referências o `ARG` variável e essa variável é alterada através da linha de comando. Neste exemplo, o comando `ENV` faz com que a imagem inclua o valor.

Se uma instrução `ENV` substitui uma instrução `ARG` de mesmo nome, como este Dockerfile:

```dockerfile
FROM ubuntu
ARG CONT_IMG_VER
ENV CONT_IMG_VER=hello
RUN echo $CONT_IMG_VER
```

A linha 3 não causa falha no cache porque o valor de `CONT_IMG_VER` é uma constante (`hello`). Como resultado, as variáveis de ambiente e valores utilizados no `RUN` (linha 4) não muda entre as compilações.

<a id="onbuild"></a>
## ONBUILD

```dockerfile
ONBUILD <INSTRUCTION>
```

A instrução `ONBUILD` adiciona à imagem uma instrução de gatilho a ser executada em um momento posterior, quando a imagem é usada como base para outra compilação. O gatilho será executado no contexto da compilação a jusante, como se tivesse sido inserido imediatamente após o `FROM` instrução no Dockerfile a jusante.

Isso é útil se você estiver construindo uma imagem que será usada como base para construir outras imagens, por exemplo, um ambiente de compilação de aplicativos ou um daemon que pode ser personalizado com a configuração específica do usuário.

Por exemplo, se a sua imagem for um construtor de aplicativos Python reutilizável, ela exigirá que o código-fonte do aplicativo seja adicionado em um diretório específico, e pode exigir que um script de compilação seja chamado depois disso. Não podes ligar `ADD` e `RUN` agora, porque você ainda não tem acesso ao código-fonte do aplicativo, e será diferente para cada compilação de aplicativos. Você pode simplesmente fornecer aos desenvolvedores de aplicativos uma placa de caldeira Dockerfile para copiar-colar em seu aplicativo, mas isso é ineficiente, propenso a erros e difícil de atualizar porque se mistura com código específico do aplicativo.

A solução é usar `ONBUILD` para registrar instruções antecipadas para executar mais tarde, durante a próxima etapa de construção.

Veja como funciona:

1. Quando encontra uma `ONBUILD` instrução, o construtor adiciona um gatilho aos metadados da imagem que está sendo construída. A instrução não afeta a compilação atual.
2. No final da compilação, uma lista de todos os gatilhos é armazenada no manifesto de imagem, sob a chave `OnBuild`. podem ser inspecionados com o comando `docker inspect`.
3. Posteriormente a imagem pode ser usada como base para uma nova compilação, utilizando o `FROM` instrução. Como parte do processamento do `FROM` instrução, o construtor downstream procura `ONBUILD` gatilhos, e executa-os na mesma ordem em que foram registrados. Se algum dos gatilhos falhar, o `FROM` instrução é abortada que por sua vez faz com que a construção falhe. Se todos os gatilhos tiverem sucesso, o `FROM` instrução completa e a construção continua como de costume.
4. Os gatilhos são eliminados da imagem final depois de serem executados. Em outras palavras, eles não são herdados por "netos" construções.

Por exemplo, você pode adicionar algo assim:

```dockerfile
ONBUILD ADD . /app/src
ONBUILD RUN /usr/local/bin/python-build --dir /app/src
```

<a id="copy-or-mount-from-stage-image-or-context"></a>
### Copiar ou montar a partir do estágio, imagem ou contexto

A partir da sintaxe do Dockerfile 1.11, você pode usar `ONBUILD` com instruções que copiam ou montam arquivos de outros estágios, imagens ou criam contextos. Por exemplo:

```dockerfile
# syntax=docker/dockerfile:1.11
FROM alpine AS baseimage
ONBUILD COPY --from=build /usr/bin/app /app
ONBUILD RUN --mount=from=config,target=/opt/appconfig ...
```

Se a fonte de `from` é um estágio de construção, o estágio deve ser definido no Dockerfile onde `ONBUILD` é acionado. Se for um contexto nomeado, esse contexto deve ser passado para a compilação downstream.

<a id="onbuild-limitations"></a>
### ONBUILD limitações

- Acorrentamento `ONBUILD` instruções usando `ONBUILD ONBUILD` não é permitido.
- A instrução `ONBUILD` não pode desencadear `FROM` ou `MAINTAINER` instruções.

<a id="stopsignal"></a>
## STOPSIGNAL

```dockerfile
STOPSIGNAL signal
```

A instrução `STOPSIGNAL` define o sinal de chamada do sistema que será enviado para o contêiner para sair. Este sinal pode ser um nome de sinal no formato `SIG<NAME>`, por exemplo `SIGKILL`, ou um número não assinado que corresponda a uma posição na tabela syscall do kernel, por exemplo `9`. O padrão é `SIGTERM` se não for definido.

`STOPSIGNAL` aplica-se ao sinal enviado por `docker stop` (e pelo daemon do Docker ao parar um recipiente). Não afeta os sinais enviados por atalhos de teclado, como o Ctrl+C, que envia `SIGINT` diretamente ao processo independentemente do `STOPSIGNAL` configuração.

O stopsignal padrão da imagem pode ser substituído por contêiner, usando o `--stop-signal` bandeira em `docker run` e `docker create`.

<a id="healthcheck"></a>
## HEALTHCHECK

A instrução `HEALTHCHECK` tem duas formas:

- `HEALTHCHECK [OPTIONS] CMD command` (verifique a saúde do contêiner executando um comando dentro do contêiner)
- `HEALTHCHECK NONE` (desative qualquer verificação de saúde herdada da imagem base)

O `HEALTHCHECK` instruções diz ao Docker como testar um contêiner para verificar se ele ainda está funcionando. Isso pode detectar casos como um servidor web preso em um loop infinito e incapaz de lidar com novas conexões, mesmo que o processo do servidor ainda esteja em execução.

Quando um recipiente tem um check-inerespecado, ele tem um estado de saúde, além de seu estado normal. Este status é inicialmente `starting`. Sempre que uma verificação de saúde passa, torna-se `healthy` (qualquer que seja o estado em que estava anteriormente). Depois de um certo número de fracassos consecutivos, torna-se `unhealthy`.

As opções que podem aparecer antes `CMD` são:

- `--interval=DURATION` (padrão: `30s`)
- `--timeout=DURATION` (padrão: `30s`)
- `--start-period=DURATION` (padrão: `0s`)
- `--start-interval=DURATION` (padrão: `5s`)
- `--retries=N` (padrão: `3`)

A verificação de saúde será executada primeiro **intervalo** segundos após o início do recipiente e, em seguida, novamente **intervalo** segundos após cada verificação anterior concluída. Durante o período de **início**, os controlos de saúde são executados em frequência **iniciar intervalo**.

Se uma única execução da verificação demorar mais de **timeout** segundos, então a verificação é considerada como tendo falhado. O processo de execução da verificação é interrompido abruptamente com um `SIGKILL`.

É preciso **retries** falhas consecutivas da verificação de saúde para que o recipiente seja considerado `unhealthy`.

**o período de início** fornece tempo de inicialização para contêineres que precisam de tempo para inicializar. A falha da sonda durante esse período não será contada para o número máximo de repetições. No entanto, se uma verificação de saúde for bem-sucedida durante o período de início, o contêiner for considerado iniciado e todas as falhas consecutivas serão contadas para o número máximo de novas.

**intervalo de início** é o tempo entre as verificações de saúde durante o período de início. Esta opção requer o Docker Engine versão 25.0 ou posterior.

Só pode haver uma instrução `HEALTHCHECK` em um Dockerfile. Se você listar mais de um, então apenas o último `HEALTHCHECK` vai fazer efeito.

O comando depois do `CMD` palavra-chave pode ser um comando shell (ex. `HEALTHCHECK CMD /bin/check-running`) ou um array exec (como com outros comandos do Dockerfile; veja e.g. `ENTRYPOINT` para detalhes).

O status de saída do comando indica o estado de saúde do contêiner. Os valores possíveis são:

- 0: sucesso - o recipiente é saudável e pronto para uso
- 1: insalubres - o recipiente não está funcionando corretamente
- 2: reservado - não use este código de saída

Por exemplo, para verificar a cada cinco minutos ou mais que um servidor da Web é capaz de servir a página principal do site em três segundos:

```dockerfile
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost/ || exit 1
```

Para ajudar a depurar sondas de falha, qualquer texto de saída (UTF-8 codificado) que o comando escreve no stdout ou stderr será armazenado no estado de saúde e pode ser consultado com `docker inspect`. Essa saída deve ser mantida curta (apenas os primeiros 4096 bytes são armazenados atualmente).

Quando o estado de saúde de um recipiente muda, a `health_status` evento é gerado com o novo status.

<a id="shell"></a>
## SHELL

```dockerfile
SHELL ["executable", "parameters"]
```

A instrução `SHELL` permite que o shell padrão usado para a forma shell de comandos seja substituído. O shell padrão no Linux é `["/bin/sh", "-c"]`, e no Windows é `["cmd", "/S", "/C"]`. A instrução `SHELL` deve ser escrita em forma JSON em um Dockerfile.

A instrução `SHELL` é particularmente útil no Windows onde existem dois shells nativos comumente usados e bastante diferentes: `cmd` e `powershell`, bem como shells alternativos disponíveis incluindo `sh`.

A instrução `SHELL` pode aparecer várias vezes. Cada uma instrução `SHELL` substitui todos os anteriores `SHELL` instruções, e afeta todas as instruções subsequentes. Por exemplo:

```dockerfile
FROM microsoft/windowsservercore

# Executed as cmd /S /C echo default
RUN echo default

# Executed as cmd /S /C powershell -command Write-Host default
RUN powershell -command Write-Host default

# Executed as powershell -command Write-Host hello
SHELL ["powershell", "-command"]
RUN Write-Host hello

# Executed as cmd /S /C echo hello
SHELL ["cmd", "/S", "/C"]
RUN echo hello
```

As instruções a seguir podem ser afetadas pelo `SHELL` instrução quando a forma de shell deles é usada em um Dockerfile: `RUN`, `CMD` e `ENTRYPOINT`.

O exemplo a seguir é um padrão comum encontrado no Windows que pode ser simplificado usando o `SHELL` instrução:

```dockerfile
RUN powershell -command Execute-MyCmdlet -param1 "c:\foo.txt"
```

O comando invocado pelo construtor será:

```powershell
cmd /S /C powershell -command Execute-MyCmdlet -param1 "c:\foo.txt"
```

Isso é ineficiente por duas razões. Primeiro, há uma desnecessária `cmd.exe` processador de comandos (aka shell) sendo invocado. Segundo, cada uma instrução `RUN` no formulário de concha requer um extra `powershell -command` prefixando o comando.

Para tornar isso mais eficiente, um dos dois mecanismos pode ser empregado. Uma é usar a forma JSON do `RUN` comando como:

```dockerfile
RUN ["powershell", "-command", "Execute-MyCmdlet", "-param1 \"c:\\foo.txt\""]
```

Enquanto a forma JSON é inequívoca e não usa o desnecessário `cmd.exe`, requer mais verbosidade através de dupla cotação e fuga. O mecanismo alternativo é usar o `SHELL` instrução e a forma shell, fazendo uma sintaxe mais natural para usuários do Windows, especialmente quando combinado com o `escape` diretiva do analisador:

```dockerfile
# escape=`

FROM microsoft/nanoserver
SHELL ["powershell","-command"]
RUN New-Item -ItemType Directory C:\Example
ADD Execute-MyCmdlet.ps1 c:\example\
RUN c:\example\Execute-MyCmdlet -sample 'hello world'
```

Resultando em:

```console
PS E:\myproject> docker build -t shell .

Sending build context to Docker daemon 4.096 kB
Step 1/5 : FROM microsoft/nanoserver
 ---> 22738ff49c6d
Step 2/5 : SHELL powershell -command
 ---> Running in 6fcdb6855ae2
 ---> 6331462d4300
Removing intermediate container 6fcdb6855ae2
Step 3/5 : RUN New-Item -ItemType Directory C:\Example
 ---> Running in d0eef8386e97


    Directory: C:\


Mode         LastWriteTime              Length Name
----         -------------              ------ ----
d-----       10/28/2016  11:26 AM              Example


 ---> 3f2fbf1395d9
Removing intermediate container d0eef8386e97
Step 4/5 : ADD Execute-MyCmdlet.ps1 c:\example\
 ---> a955b2621c31
Removing intermediate container b825593d39fc
Step 5/5 : RUN c:\example\Execute-MyCmdlet 'hello world'
 ---> Running in be6d8e63fe75
hello world
 ---> 8e559e9bf424
Removing intermediate container be6d8e63fe75
Successfully built 8e559e9bf424
PS E:\myproject>
```

A instrução `SHELL` também poderia ser usado para modificar a maneira pela qual um shell opera. Por exemplo, usando `SHELL cmd /S /C /V:ON|OFF` no Windows, a semântica de expansão variável de ambiente atrasado poderia ser modificada.

A instrução `SHELL` também pode ser usado no Linux caso um shell alternativo seja necessário, como `zsh`, `csh`, `tcsh` e outros.

<a id="here-documents"></a>
## Here-documents

Aqui-documentos permitem o redirecionamento de linhas subsequentes do Dockerfile para a entrada de `RUN` ou `COPY` comandos. Se tal comando contém um [aqui-documento](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_07_04) o Dockerfile considera as próximas linhas até a linha contendo apenas um delimitador aqui-doc como parte do mesmo comando.

<a id="example-running-a-multi-line-script"></a>
### Exemplo: Executando um script de várias linhas

```dockerfile
# syntax=docker/dockerfile:1
FROM debian
RUN <<EOT bash
  set -ex
  apt-get update
  apt-get install -y vim
EOT
```

Se o comando contém apenas um documento aqui, seu conteúdo é avaliado com o shell padrão.

```dockerfile
# syntax=docker/dockerfile:1
FROM debian
RUN <<EOT
  mkdir -p foo/bar
EOT
```

Alternativamente, o cabeçalho shebang pode ser usado para definir um intérprete.

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.6
RUN <<EOT
#!/usr/bin/env python
print("hello world")
EOT
```

Exemplos mais complexos podem usar vários documentos aqui.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
RUN <<FILE1 cat > file1 && <<FILE2 cat > file2
I am
first
FILE1
I am
second
FILE2
```

<a id="example-creating-inline-files"></a>
### Exemplo: Criação de arquivos inline

Com `COPY` instruções, você pode substituir o parâmetro de origem por um indicador aqui-doc para escrever o conteúdo do documento aqui diretamente para um arquivo. O exemplo a seguir cria a `greeting.txt` arquivo contendo `hello world` usando a `COPY` instrução.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
COPY <<EOF greeting.txt
hello world
EOF
```

Regular aqui-doc [expansão variável e regras de decapagem de guias](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_07_04) aplicar. O exemplo a seguir mostra um pequeno Dockerfile que cria um `hello.sh` arquivo de script usando uma instrução `COPY` com um aqui-documento.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
ARG FOO=bar
COPY <<-EOT /script.sh
  echo "hello ${FOO}"
EOT
ENTRYPOINT ash /script.sh
```

Nesse caso, o script de arquivo imprime "hello bar", porque a variável é expandida quando o `COPY` instrução é executada.

```console
$ docker build -t heredoc .
$ docker run heredoc
hello bar
```

Se, em vez disso, você fosse citar qualquer parte da palavra aqui-documento `EOT`, a variável não seria expandida em tempo de construção.

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
ARG FOO=bar
COPY <<-"EOT" /script.sh
  echo "hello ${FOO}"
EOT
ENTRYPOINT ash /script.sh
```

Observe que `ARG FOO=bar` é excessivo aqui, e pode ser removido. A variável é interpretada em tempo de execução, quando o script é invocado:

```console
$ docker build -t heredoc .
$ docker run -e FOO=world heredoc
hello world
```

<a id="dockerfile-examples"></a>
## Exemplos do Dockerfile

Para exemplos de Dockerfiles, consulte:

- A [página de melhores práticas de construção](https://docs.docker.com/build/building/best-practices/)
- Os tutoriais ["começar"](https://docs.docker.com/get-started/)
- Os [guias de início específicos da linguagem](https://docs.docker.com/guides/language/)

[^1]: /reference/Valor obrigatório
[^2]: /reference/Para o BuildKit integrado ao Docker [BuildKit](https:/docs.docker.com/build/buildkit#getting-started) e `docker buildx build`


