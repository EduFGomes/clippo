# 05 — Conteúdo e voz

Todo texto do app — botões, avisos, estados vazios, erros, notificações — segue este guia.

## Tom de voz

O Clippo fala como **um amigo do time que entende de tecnologia**: direto, animado na hora certa, nunca técnico.

| Somos | Não somos |
|---|---|
| **Curtos.** Quem lê está suado, na quadra, a metros do celular. | Explicativos, com parágrafos. |
| **Diretos.** Verbo na frente: "Gravar", "Salvar sessão". | Passivos: "A sessão foi salva com sucesso pelo sistema". |
| **Energéticos no momento do lance.** "Highlight salvo". | Eufóricos o tempo todo, com exclamações e emojis em tudo. |
| **Informais, em PT-BR.** Tratamos por "você". | Formais ("o usuário deverá…") ou com gírias forçadas. |
| **Claros sobre problemas.** "Sem internet. Seus highlights sobem quando conectar." | Técnicos ("Erro 503", "Falha na sincronização do bucket"). |

## Regras de escrita

- **Frase normal**, não Título Com Cada Palavra Maiúscula.
- **Botões com verbo**, 1 a 3 palavras: "Gravar", "Salvar sessão", "Tentar de novo", "Convidar".
- **Sem ponto final** em botões, títulos, chips e avisos curtos. Com ponto final em frases completas de texto corrido.
- **Números em algarismos**: "3 sessões juntos", "7 highlights". Durações: "1h 42min", "58min".
- **Datas**: "11 set 2026"; horários "19:30 – 21:12". 🟡 Para sessões recentes, "Hoje" e "Ontem" podem substituir a data.
- **Momento dentro da sessão**: "00:12:40" (horas:minutos:segundos desde o início da gravação), seguido da duração do trecho: "00:12:40 · 30s".
- Evite exclamação; no máximo uma, e só em comemoração.
- Sem emojis na interface.
- Separador de informações na mesma linha: ponto médio com espaços ( · ).

## Microcopy de referência

Textos que já estão no [protótipo](prototipos/README.md) — use exatamente assim.

| Onde | Texto |
|---|---|
| Início — saudação | Boa noite, Gustavo *(Bom dia / Boa tarde / Boa noite + primeiro nome)* |
| Início — título | Suas sessões |
| Card de sessão | 11 set 2026 · 7 highlights |
| Card aberto — botão | Ver highlights |
| Participantes | 10 participantes |
| Sessão — voltar | Sessões |
| Sessão — seção | Highlights · 7 lances salvos |
| Linha de highlight | 00:12:40 · 30s |
| Gravação — dica | Apoie o celular e enquadre o campo |
| Gravação — rótulo dos chips | Gravar com |
| Chip padrão | Gravar sozinho |
| Chip de amigo | Com Rafa *(primeiro nome)* |
| Legenda do botão de gravar | Iniciar detecção de gesto \ o / |
| Aviso ao salvar | **Highlight salvo** · últimos 30s · gesto \ o / detectado |
| Controles do standby | Encerrar sessão · Cancelar gravação |
| Fim — voltar | Voltar à câmera |
| Fim — resumo | Gravação encerrada · 4 highlights |
| Fim — título | Confirme a sessão |
| Fim — rótulos | Nome da sessão · Data · Horário · Local · sugerido por GPS · Participantes |
| Fim — participante você | Você |
| Fim — adicionar | + adicionar |
| Fim — ações | Salvar sessão · Descartar |
| Amigos — botão | Convidar |
| Amigos — busca | Buscar amigo ou usuário |
| Amigos — linha secundária | 12 sessões juntos · nenhuma sessão ainda |
| Perfil — estatísticas | sessões · highlights · amigos |
| Perfil — linhas | Nome · Usuário · Notificações |
| Sair | Sair da conta |

Textos para estados que o protótipo ainda não mostra 🟡:

| Onde | Texto |
|---|---|
| Início vazio — título | Nenhuma sessão ainda |
| Início vazio — texto | Posicione o celular, comece a gravar e faça \ o / quando rolar um lance bom. |
| Início vazio — botão | Gravar primeira sessão |
| Sessão sem highlights | Nenhum lance salvo nessa sessão |
| Highlight ainda subindo | enviando… |
| Sem internet | Sem internet. Seus highlights sobem quando conectar. |
| Erro genérico | Algo deu errado. |
| Botão de erro | Tentar de novo |
| Amigos vazio | Adicione quem joga com você |
| Permissão de câmera | O Clippo precisa da câmera para gravar os lances. |
| Permissão de localização | Usamos sua localização só para sugerir o local da sessão. |
| Frase-assinatura | Levantou os braços, o lance está salvo. |

## Highlight, lance e sessão

- **Highlight** é o nome do trecho salvo — em botões, avisos e contadores ("Ver highlights", "Highlight salvo", "7 highlights"). Não use "clipe".
- **Lance** é a palavra do jogo, usada só em frases ("7 lances salvos", "Nenhum lance salvo nessa sessão").
- **Sessão** é o jogo gravado. Não use "partida", "jogo" ou "pasta" na interface.

## Glossário

Termo na interface (PT-BR) → nome no código (EN). Use sempre o nome em inglês em classes, variáveis, campos, rotas e coleções.

| Interface | Código | Observação |
|---|---|---|
| Usuário / você | `User` | |
| Perfil | `Profile` | Tela e dados públicos do usuário. |
| Nome de usuário (@) | `username` | |
| Amigo | `Friend` | |
| Amizade / convite | `Friendship` / `FriendInvite` | |
| Sessão | `Session` | Um jogo gravado; é a "pasta compartilhada". |
| Dono da sessão | `owner` | Quem iniciou a gravação. |
| Participante | `Participant` | |
| Highlight | `Highlight` | Trecho salvo pelo gesto. |
| Miniatura | `thumbnail` | |
| "00:12:40" | `offset` | Momento do highlight dentro da sessão. |
| Local | `location` | |
| Duração | `duration` | |
| Gesto \ o / | `Gesture` | |
| Disparo do gesto | `trigger` | |
| Buffer de 30 s | `Buffer` / `ringBuffer` | |
| Gravação (tela/fluxo) | `Capture` | Estados: `preparing`, `recording`, `saved`, `finishing`. |
| Início (tela) | `Home` | |
| Amigos (tela) | `Friends` | |
