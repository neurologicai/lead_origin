# LeadOrigin

Gem Ruby interna da Leadster para identificar o canal de aquisição de um lead a partir de uma URL e seus parâmetros.

## Sumário

- [Instalação](#instalação)
- [Uso](#uso)
- [Canais retornados](#canais-retornados)
- [Regras de negócio](#regras-de-negócio)
  - [Prioridade de detecção](#prioridade-de-detecção)
  - [1. Click IDs (maior prioridade)](#1-click-ids-maior-prioridade)
  - [2. Parâmetro UTM Source](#2-parâmetro-utm-source)
  - [3. Referrer HTTP](#3-referrer-http)
- [Comportamentos especiais](#comportamentos-especiais)
- [Compatibilidade](#compatibilidade)
- [Desenvolvimento](#desenvolvimento)

---

## Instalação

Adicione ao `Gemfile` do projeto, referenciando via caminho local ou repositório Git:

```ruby
# via caminho local
gem "lead_origin", path: "../lead_origin"

# via repositório Git
gem "lead_origin", git: "https://github.com/neurologicai/lead_origin"
```

> **Requisito:** a gem utiliza `ActiveSupport::Object#blank?`, portanto requer que o ActiveSupport esteja carregado na aplicação host (qualquer aplicação Rails já satisfaz esse requisito).

---

## Uso

A interface pública é o método `LeadOrigin.detect`, que recebe a URL da página onde o lead foi capturado e, opcionalmente, o cabeçalho HTTP Referer.

```ruby
LeadOrigin.detect(url:, referrer: nil) # => Symbol ou nil
```

### Exemplos

```ruby
# Detectado via Click ID
LeadOrigin.detect(url: "https://site.com/landing?fbclid=abc123")
# => :facebook

LeadOrigin.detect(url: "https://site.com/landing?gclid=xyz789")
# => :google

LeadOrigin.detect(url: "https://site.com/landing?li_fat_id=def456")
# => :linkedin

# Detectado via UTM source
LeadOrigin.detect(url: "https://site.com/landing?utm_source=google&utm_medium=cpc")
# => :google

LeadOrigin.detect(url: "https://site.com/landing?utm_source=facebook&utm_campaign=black_friday")
# => :facebook

LeadOrigin.detect(url: "https://site.com/landing?utm_source=fb")
# => :facebook

LeadOrigin.detect(url: "https://site.com/landing?utm_source=linkedin")
# => :linkedin

LeadOrigin.detect(url: "https://site.com/landing?utm_source=newsletter")
# => nil

# Detectado via Referrer
LeadOrigin.detect(url: "https://site.com/landing", referrer: "https://blog.parceiro.com")
# => :organic

# Sem informações de origem
LeadOrigin.detect(url: "https://site.com/landing")
# => nil
```

### Usando a classe diretamente

Também é possível instanciar `LeadOrigin::Detector` para reaproveitar a instância:

```ruby
detector = LeadOrigin::Detector.new(url: "https://site.com?gclid=abc", referrer: nil)
detector.detect
# => :google
```

---

## Canais retornados

| Símbolo     | Descrição                                                                      |
|-------------|--------------------------------------------------------------------------------|
| `:google`   | Tráfego originado do Google (pago ou orgânico via UTM/gclid)                   |
| `:facebook` | Tráfego originado do Facebook/Meta (via fbclid ou utm_source)                  |
| `:linkedin` | Tráfego originado do LinkedIn (via li_fat_id ou utm_source)                    |
| `:organic`  | Tráfego com referrer externo presente e sem parâmetros de rastreamento         |
| `nil`       | Sem informações de origem identificáveis                                       |


---

## Regras de negócio

### Prioridade de detecção

A detecção segue uma cadeia de prioridade estrita. A primeira regra que produzir um resultado encerra a análise:

```
Click ID  >  UTM source  >  Referrer
```

### 1. Click IDs (maior prioridade)

Click IDs são parâmetros adicionados automaticamente pelas plataformas de anúncio na URL de destino no momento do clique. Por serem injetados pela plataforma (e não pela campanha), têm precedência sobre os UTMs.

| Parâmetro   | Canal detectado |
|-------------|-----------------|
| `fbclid`    | `:facebook`     |
| `gclid`     | `:google`       |
| `li_fat_id` | `:linkedin`     |

**Regra:** basta a presença do parâmetro na URL, independentemente do seu valor.

```
https://site.com?fbclid=abc&utm_source=google  =>  :facebook
# O fbclid prevalece sobre o utm_source=google
```

### 2. Parâmetro UTM Source

Quando não há click ID, o parâmetro `utm_source` é analisado por correspondência de padrão (case-insensitive):

| Padrão (`utm_source`)     | Canal detectado |
|---------------------------|-----------------|
| contém `facebook` ou `fb` | `:facebook`     |
| contém `google`           | `:google`       |
| contém `linkedin`         | `:linkedin`     |
| qualquer outro valor      | `nil`           |

> Se `utm_source` estiver ausente, esta etapa é ignorada.

**Exemplos de valores que são mapeados:**

| `utm_source`       | Canal       |
|--------------------|-------------|
| `google`           | `:google`   |
| `Google`           | `:google`   |
| `facebook`         | `:facebook` |
| `Facebook`         | `:facebook` |
| `fb`               | `:facebook` |
| `linkedin`         | `:linkedin` |
| `newsletter`       | nil         |
| `email`            | nil         |
| `parceiro_xpto`    | nil         |

### 3. Referrer HTTP

Quando não há click ID nem UTM source, o cabeçalho HTTP Referer é verificado.

- **Referrer presente, sem parâmetros de rastreamento** → `:organic`
- **Referrer presente com click ID (`fbclid`, `gclid`, `li_fat_id`) e mesmo domínio da URL** → canal correspondente ao click ID
- **Referrer com parâmetros de rastreamento em domínio diferente** → `nil` (ignorado)
- **Referrer ausente, `nil` ou apenas espaços em branco** → `nil`

> Parâmetros de rastreamento considerados: `fbclid`, `gclid`, `li_fat_id` e qualquer parâmetro com prefixo `utm_`.

---

## Comportamentos especiais

### URL inválida ou ausente

Quando a URL é `nil`, vazia ou malformada, a detecção via parâmetros (click IDs e UTM) é ignorada e o fluxo cai direto na verificação do referrer.

```ruby
LeadOrigin.detect(url: nil)                                              # => nil
LeadOrigin.detect(url: "")                                               # => nil
LeadOrigin.detect(url: "nao_é_uma_url")                                  # => nil (sem crash)
LeadOrigin.detect(url: nil, referrer: "https://www.google.com/search")   # => :organic
LeadOrigin.detect(url: nil, referrer: "https://www.bing.com/search")     # => :organic
```

### Referrer em branco

Strings de referrer compostas apenas por espaços são tratadas como ausentes.

```ruby
LeadOrigin.detect(url: "https://site.com", referrer: "   ") # => nil
```

### Click ID prevalece sobre UTM

Quando a URL contém tanto um click ID quanto um `utm_source`, o click ID sempre vence.

```ruby
# utm_source diz google, mas o fbclid diz facebook
LeadOrigin.detect(url: "https://site.com?fbclid=abc&utm_source=google")
# => :facebook
```

### UTM prevalece sobre Referrer

Quando há `utm_source` e um referrer ao mesmo tempo, o UTM sempre vence.

```ruby
LeadOrigin.detect(
  url: "https://site.com?utm_source=google",
  referrer: "https://algum-site.com"
)
# => :google
```

### Referrer com click ID no mesmo domínio

Quando a URL não possui parâmetros de rastreamento, mas o referrer é do mesmo domínio e contém um click ID, o canal é detectado a partir do referrer.

```ruby
LeadOrigin.detect(
  url: "https://site.com/obrigado",
  referrer: "https://site.com/?fbclid=abc123"
)
# => :facebook
```

### Referrer com click ID em domínio diferente é ignorado

Se o referrer pertence a um domínio diferente e contém parâmetros de rastreamento, ele é ignorado.

```ruby
LeadOrigin.detect(
  url: "https://site.com/pagina",
  referrer: "https://outro-dominio.com/?fbclid=abc123"
)
# => nil
```

---

## Compatibilidade

| Requisito         | Versão          |
|-------------------|-----------------|
| Ruby              | `>= 2.6.0`      |
| ActiveSupport     | `>= 5.2` (já disponível em qualquer app Rails) |

A gem não possui dependências de runtime externas além do ActiveSupport. Utiliza apenas `URI` e `CGI` da biblioteca padrão do Ruby.

---

## Desenvolvimento

### Pré-requisitos

```bash
bundle install
```

### Executar os testes

```bash
bundle exec rspec
```

### Estrutura

```
lead_origin/
├── lib/
│   ├── lead_origin.rb              # Ponto de entrada: LeadOrigin.detect
│   └── lead_origin/
│       ├── version.rb              # Versão da gem
│       └── detector.rb             # Lógica de detecção de canal
├── spec/
│   ├── spec_helper.rb
│   └── lead_origin/
│       └── detector_spec.rb        # Testes unitários
├── .rubocop.yml                    # Configuração de linting (Ruby 2.6.10)
├── Gemfile
└── lead_origin.gemspec
```
