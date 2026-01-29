# odbc_fast – Como obter a DLL (odbc_engine.dll)

Resumo da documentação do [odbc_fast](https://pub.dev/packages/odbc_fast) e do repositório [dart_odbc_fast](https://github.com/cesar-carlos/dart_odbc_fast).

---

## 1. Visão geral

- O motor ODBC é uma **biblioteca nativa em Rust**.
- No Windows o binário é **`odbc_engine.dll`**; no Linux, **`libodbc_engine.so`**.
- O pacote usa **Dart Native Assets**: no primeiro uso o binário pode ser baixado do GitHub Releases e cacheado em `~/.cache/odbc_fast/`.
- Se o download automático falhar ou não rodar (ex.: em Flutter/`dart test`), a DLL precisa estar acessível por **PATH** ou por **cópia manual**.

---

## 1.1 Por que o `flutter pub get` não baixa e coloca a DLL sozinho?

**Comportamento esperado:** Ao rodar `dart pub get` ou `flutter pub get`, um **hook de build** (Native Assets) deveria:

1. Baixar a DLL compilada (do GitHub Releases ou do próprio pacote).
2. Gravar em um local conhecido (ex.: `~/.cache/odbc_fast/<versão>/`).
3. **Registrar** o asset para que `DynamicLibrary.open('package:odbc_fast/odbc_engine.dll')` funcione na execução.

**O que acontece na prática (até versões que não publicavam o hook):** Em versões antigas, o pacote publicado no pub.dev **não incluía a pasta `hook/`** (onde fica o `hook/build.dart` que faz o download e o registro). A partir das versões em que `hook/` e `scripts/` passaram a ser publicados, o hook pode rodar no consumidor e o script `scripts/copy_odbc_dll.ps1` está disponível no pacote. Se ainda assim o carregamento falhar:

- O hook **não roda** no projeto consumidor quando você faz `pub get` ou build.
- A opção 1 do `library_loader.dart` (`package:odbc_fast/odbc_engine.dll`) **nunca** é preenchida pelo sistema de Native Assets.
- O loader cai direto no **fallback** (opção 3): `DynamicLibrary.open('odbc_engine.dll')`, que só encontra a DLL se ela estiver no diretório atual ou no PATH — ou seja, **não há download nem cópia automática** para o app/teste.

**Consequência:** Se o Native Assets não preencher a opção 1, use **workaround**: copiar a DLL do cache do pub (`...\odbc_fast-<versão>\artifacts\windows-x64\odbc_engine.dll`) para a raiz do projeto ou para a pasta do executável, ou rodar o script `scripts/copy_odbc_dll.ps1` do pacote (seção 7).

**Estado atual:** O repositório passou a publicar a pasta `hook/` e a pasta `scripts/` (incluindo `scripts/copy_odbc_dll.ps1`). Nas próximas versões publicadas no pub.dev, o hook poderá rodar no consumidor e o script de cópia estará disponível no pacote.

---

## 2. Obter a DLL sem compilar (consumidor do pacote)

### 2.1 Download automático (recomendado pela documentação)

Na raiz do seu projeto (ex.: `demo_odbc`):

```bash
dart pub get
```

- Na **primeira execução**, o mecanismo de Native Assets pode baixar o binário do GitHub Releases e gravar em `~/.cache/odbc_fast/`.
- Se o carregamento ainda falhar (ex.: `error code 126`), use uma das opções abaixo.

### 2.2 Cópia a partir do cache do pub

O pacote publicado já traz a DLL em:

```
Pub Cache\hosted\pub.dev\odbc_fast-<versão>\artifacts\windows-x64\odbc_engine.dll
```

Exemplo no Windows:

```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\odbc_fast-0.2.6\artifacts\windows-x64\odbc_engine.dll
```

**Workaround para rodar app/testes:**

1. Copie `odbc_engine.dll` para uma pasta que esteja no **PATH** ao executar o app, **ou**
2. Copie para a pasta do executável (ex.: `build\windows\x64\runner\Release\` após `flutter build windows`), **ou**
3. Coloque no diretório de trabalho quando rodar `flutter run` ou `dart test`.

Assim o `library_loader.dart` consegue carregar via terceira opção: `DynamicLibrary.open(name)` (sistema/PATH).

### 2.3 Baixar a DLL sozinha (direto do GitHub)

Para **não depender do pub cache** (ex.: CI, máquina limpa, ou quando o pacote ainda não foi instalado), use o script que baixa a DLL diretamente do [GitHub Releases](https://github.com/cesar-carlos/dart_odbc_fast/releases) e já a copia para as pastas do runner e para a raiz do projeto:

```powershell
.\scripts\download_odbc_dll.ps1
```

Versão específica (ex.: 0.2.8):

```powershell
.\scripts\download_odbc_dll.ps1 -Version 0.3.0
```

O script:

1. Consulta a API do GitHub pela release `v<versão>`.
2. Baixa o asset Windows (`.dll` ou `.zip` com a DLL).
3. Copia `odbc_engine.dll` para `build\windows\x64\runner\Debug`, `Release` e para a raiz do projeto.

Requer acesso à internet e que o repositório `dart_odbc_fast` publique os binários nas releases.

---

## 3. Gerar a DLL compilando do código-fonte

Recomendado se você for contribuir com o odbc_fast ou precisar de um build específico.

### 3.1 Pré-requisitos (Windows)

- **Rust** (toolchain MSVC):
  ```powershell
  winget install Rustlang.Rust.MSVC
  ```
- **Dart SDK** (já tem com Flutter).
- ODBC Driver Manager (já vem no Windows).

### 3.2 Clone e build no repositório do odbc_fast

O código-fonte (incluindo `native/odbc_engine`) está no repositório **dart_odbc_fast**, não no seu app:

```powershell
git clone https://github.com/cesar-carlos/dart_odbc_fast.git
cd dart_odbc_fast
```

**Opção A – Script de build (recomendado pela documentação):**

```powershell
.\scripts\build.ps1
```

O script:

1. Compila o Rust em release: `native\odbc_engine`, `cargo build --release`
2. Opcionalmente gera bindings Dart (ffigen)
3. Verifica se a DLL foi gerada

**Opção B – Build manual só da engine:**

```powershell
cd dart_odbc_fast\native
cargo build --release
```

Saída:

- Windows: `native\odbc_engine\target\release\odbc_engine.dll`
- Ou, dependendo da estrutura: `native\target\release\odbc_engine.dll`

(Conforme [doc/BUILD.md](https://github.com/cesar-carlos/dart_odbc_fast/blob/main/doc/BUILD.md): Windows `native/target/release/odbc_engine.dll` ou `native/odbc_engine/target/release/odbc_engine.dll`.)

### 3.3 Usar a DLL gerada no seu projeto (demo_odbc)

- Copie a `odbc_engine.dll` gerada para o mesmo tipo de lugar que na seção 2.2 (PATH ou pasta do executável / de trabalho), **ou**
- Use o odbc_fast como dependência **path** apontando para o clone do `dart_odbc_fast` onde você rodou o build (aí o loader pode usar os caminhos de “desenvolvimento local” dentro daquele repo).

---

## 4. Ordem de carregamento no odbc_fast (library_loader.dart)

O pacote tenta, nesta ordem:

1. **Native Assets**: `DynamicLibrary.open('package:odbc_fast/odbc_engine.dll')`  
   (depende do hook/build e do processo de build do app que consome o pacote.)
2. **Desenvolvimento local** (dentro do repo dart_odbc_fast):
   - `native/target/release/odbc_engine.dll`
   - `native/odbc_engine/target/release/odbc_engine.dll`
3. **Sistema**: `DynamicLibrary.open('odbc_engine.dll')`  
   (DLL no PATH ou no diretório atual.)

Se 1 e 2 não existirem no seu cenário (ex.: app Flutter que só tem o pacote via pub), fazer a DLL estar disponível para 3 resolve o “ODBC engine library not found”.

---

## 5. Referências

- [pub.dev – odbc_fast](https://pub.dev/packages/odbc_fast)
- [README – dart_odbc_fast](https://github.com/cesar-carlos/dart_odbc_fast#readme)
- [doc/BUILD.md](https://github.com/cesar-carlos/dart_odbc_fast/blob/main/doc/BUILD.md) – build e desenvolvimento
- [doc/TROUBLESHOOTING.md](https://github.com/cesar-carlos/dart_odbc_fast/blob/main/doc/TROUBLESHOOTING.md) – problemas comuns
- [Releases (binários pré-compilados)](https://github.com/cesar-carlos/dart_odbc_fast/releases)

---

## 6. Resumo prático para demo_odbc (Windows)

| Objetivo            | Ação                                                                                                                                                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Só rodar app/testes | Na raiz do seu projeto: `& "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\odbc_fast-<versão>\scripts\copy_odbc_dll.ps1"` (substitua `<versão>` por ex. `0.3.0`). Depois: `flutter run -d windows` ou `dart test`. Ou use cópia manual (seção 2.2). |
| Cópia manual        | Copiar `odbc_engine.dll` do cache do pub (`...\odbc_fast-0.3.0\artifacts\windows-x64\`) para a pasta do executável ou para uma pasta no PATH.                                                                                                   |
| Garantir download   | Rodar `dart pub get` no projeto. A partir de versões que publicam o `hook/`, o Native Assets pode baixar a DLL automaticamente; se falhar, use o script acima ou a cópia manual.                                                                |
| Compilar a DLL você | Clonar `dart_odbc_fast`, instalar Rust MSVC, rodar `.\scripts\build.ps1` (ou `cargo build --release` em `native/`) e usar a DLL gerada como na cópia acima.                                                                                     |

---

## 7. Script de cópia automática (Windows)

O pacote inclui `scripts/copy_odbc_dll.ps1`, que copia `odbc_engine.dll` do pacote (pub cache ou clone do repo) para a raiz do seu projeto e para as pastas do Flutter runner. **Como usar (na raiz do seu projeto):**

```powershell
& "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\odbc_fast-0.3.0\scripts\copy_odbc_dll.ps1"
```

Substitua `0.3.0` pela versão do odbc_fast que você usa. O script usa o diretório atual como projeto de destino.

**O que o script faz:**

1. Lê o pacote odbc_fast a partir do diretório do script (pub cache ou repo).
2. Copia `artifacts\windows-x64\odbc_engine.dll` para:
   - Raiz do projeto (`odbc_engine.dll`) para `dart test`.
   - `build\windows\x64\runner\Debug\` (para `flutter run -d windows` em Debug).
   - `build\windows\x64\runner\Release\` (para build Release).

**Quando usar:** após o primeiro `dart pub get` ou sempre que aparecer “ODBC engine library not found”. A DLL na raiz está no `.gitignore` e não é versionada.

---

## 8. Análise do mantenedor

**Resumo:** O relatório estava correto. As seguintes alterações foram feitas no repositório:

### Alterações aplicadas

| Item                                   | Antes                              | Depois                                                                                                                                                                                             |
| -------------------------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Pasta `hook/`**                      | Excluída do pacote (`.pubignore`). | **Incluída no pacote** — `hook` e `scripts/` removidos do `.pubignore`. O hook passa a ser publicado e pode rodar no consumidor (download/cache automático da DLL).                                |
| **Script `scripts/copy_odbc_dll.ps1`** | Não existia.                       | **Criado.** Copia a DLL do pacote (pub cache) para a raiz do projeto e para `build\windows\x64\runner\Debug` e `Release`. O consumidor pode executar o script pelo caminho do pacote no pub cache. |

### Verificação no repositório (atual)

- **Hook:** Publicado no pacote; o build do app consumidor pode executar o hook e preencher a opção 1 (`package:odbc_fast/odbc_engine.dll`).
- **Script de cópia:** Existe em `scripts/copy_odbc_dll.ps1` e é publicado junto com a pasta `scripts/`.
- **Fallback (opção 3):** Continua válido; o `library_loader.dart` mantém a mesma ordem de carregamento.
