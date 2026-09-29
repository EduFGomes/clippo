# 01 — Produto

## Em uma frase

O Clippo é um app Android que grava continuamente os últimos 30 segundos de uma partida amadora e, quando um jogador faz o gesto **\ o /** para a câmera, salva esse trecho como um *highlight* visível para todos que jogaram juntos.

## O problema

Em peladas, futebol society e jogos casuais, os melhores lances acontecem e ninguém grava. Quando alguém pega o celular, o momento já passou. Gravar a partida inteira gera horas de vídeo que ninguém assiste nem edita.

## A proposta

1. O jogador apoia o próprio celular em algum ponto da quadra, onde quiser — sem tripé ou posição fixa.
2. Inicia uma **sessão**. O app passa a manter na memória, o tempo todo, só os últimos 30 segundos de vídeo.
3. Aconteceu um lance bom? Qualquer jogador olha para o celular e levanta os dois braços abertos em diagonal: **\ o /**.
4. O app reconhece o gesto e salva os 30 segundos anteriores como um **highlight**. Ninguém precisa tocar no celular.
5. Ao fim do jogo, todos os participantes da sessão encontram os highlights no app.

O valor está em **não precisar fazer nada** durante o jogo além do gesto — e em ter só os melhores momentos, não a partida inteira.

## O gesto

- Os **dois braços levantados**, abertos para fora e para cima, em diagonal — como um "Y" ou uma comemoração.
- Braços **não cruzados**. A opção em "X" foi descartada porque, com os braços se sobrepondo, a detecção de pose confunde os lados esquerdo e direito.
- O jogador faz o gesto **de propósito, olhando para a câmera**, o que ajuda a evitar disparos acidentais em comemorações espontâneas.
- A detecção acontece **no próprio celular**, em tempo real, usando um modelo de pose pronto (pontos do corpo) e uma regra geométrica sobre esses pontos — sem treinar um modelo do zero.

## Público

Jogadores amadores que organizam partidas casuais com amigos, em grupo. Não são atletas profissionais nem editores de vídeo; querem algo que funcione sozinho e renda um vídeo para mandar no grupo.

## Personalidade do produto

Escuro, esportivo e vibrante — na linha de Strava e Nike. Referências de experiência: Strava, GymRats, Instagram, YouTube, X. O app precisa reagir com a mesma energia da jogada que acabou de acontecer. Detalhes em [04 — Design system](04-design-system.md) e [05 — Conteúdo e voz](05-conteudo-e-voz.md).

## Escopo do MVP

| Entra | Fica de fora |
|---|---|
| App Android com as telas descritas em [03 — Telas](03-telas.md) | Versão iOS 🟡 *(não descartada para o futuro)* |
| Detecção do gesto no aparelho | Edição de vídeo dentro do app |
| Buffer de 30 s e salvamento automático | Transmissão ao vivo |
| Sessões compartilhadas entre participantes | Publicação aberta na Play Store (só teste interno) |
| Amigos e perfil | Monetização |
| Documentação e demo ao vivo | |

## Critérios de aceite

O projeto está pronto quando:

- O gesto é reconhecido em **≥ 90 % das tentativas a até 8 m** da câmera.
- O highlight é salvo em **até 3 s** depois do gesto.
- O highlight fica **visível para todos os participantes** da sessão.
- A **demo ao vivo** roda do começo ao fim sem falha.

## Premissas e restrições

- Modelo de pose pré-treinado, sem treino de modelo próprio.
- 5 pessoas, cerca de 6 h por semana cada.
- Período: 27/08 a 04/12/2026 (entrega final ainda depende de aprovação do orientador 🟡).
- Só Android no MVP.
- Critério de desempate em qualquer decisão: **o que deixa a demo ao vivo mais convincente** para quem não é técnico.
