# 🏏 Brainrot Tycoon: Caça e Captura

Jogo de Roblox onde você **bate nos brainrots com um taco de beisebol**, **captura eles com bolas**
(quanto **menos vida** o brainrot tiver, **maior a chance** de pegar), **luta usando seus brainrots como parceiros**
(eles ganham XP, sobem de nível, aprendem ataques e **evoluem**) e coloca eles na sua **base (tycoon)**
para ganhar dinheiro por segundo.

## Como jogar

1. Você nasce na sua base. Pegue o **🏏 Taco** (tecla 1) e vá até a **Zona de Caça** no meio do mapa.
2. Bata nos brainrots. Eles **ficam bravos e atacam de volta**!
3. Quando a vida estiver baixa (barra amarela/vermelha), pegue a **⚪ Bola** (tecla 2) e clique no brainrot.
   - Passe o mouse em cima do brainrot para ver a **🎯 chance de captura**.
   - Vida cheia = chance normal. Quase sem vida = **3x mais chance**.
   - Se a vida **zerar**, ele **desmaia e foge** (você ganha só um pouquinho de dinheiro).
   - Se ele escapar da bola, fica bravo de novo e a vida continua baixa. Tente outra vez!
   - Depois de alguns segundos sem apanhar, ele **regenera** a vida.
4. Volte para a base (botão **🏠 Base**) e use o pedestal (segure **E**) para **colocar** o brainrot.
5. Cada brainrot no pedestal gera **$ por segundo**. Pise no **coletor verde** para pegar o dinheiro.
6. Use o dinheiro na **🛒 Loja**: bolas melhores, tacos mais fortes e mais pedestais.
7. No menu **🎒 Brainrots**, aperte **⚔ Lutar** para escolher um **parceiro** (veja abaixo).

### ⚔ Parceiro de batalha

- O parceiro **te segue** e **luta contra os brainrots selvagens**. Os selvagens **revidam** e podem nocautear ele.
- Ele ataca quem você bater com o taco e quem atacar você. Com o **Auto LIGADO**, ataca qualquer selvagem perto de você.
- Se você estiver **segurando a Bola** e o selvagem estiver com **pouca vida**, o parceiro **para de bater** para você capturar.
- Se o parceiro desmaiar, ele volta em **20 segundos**. Fora de combate ele recupera vida sozinho.
- Cada selvagem **derrotado** dá **XP** para o parceiro (selvagens mais raros e de nível mais alto dão mais).
  Capturar um brainrot com o parceiro do lado também dá metade do XP.
- **Cada nível:** +8% de vida, +8% de força e +10% de renda no pedestal. Nível máximo: 50.
- **Evolução:** no **nível 15** e no **nível 30** ele evolui: muda de nome, fica maior, ganha aura (e coroa na
  evolução final), muito mais vida/força e rende **1,5x** e depois **2,5x** mais na base.

| Nível | Ataque novo | Tecla |
|---|---|---|
| 1 | Ataque (automático) | — |
| 5 | Cabeçada (corpo a corpo forte) | Z |
| 10 | Rajada Brainrot (de longe) | X |
| 20 | Terremoto (acerta todos em volta) | C |
| 30 | **Golpe especial** de cada brainrot (ex.: *Tung Tung Tung!*, *Tsunami Tralala*, *Bombardeio*) | V |

Mire com o mouse no brainrot e aperte a tecla (ou toque no botão do ataque na tela).

> Os selvagens também têm **nível** (Comum Lv.1–5 até Mítico Lv.15–20). Quando você captura, o brainrot vem
> com o nível que tinha!

### Raridades

Vida e renda abaixo são no **nível 1** (aumentam com o nível).

| Raridade | Exemplos | Vida | Chance base | Renda | Nível selvagem |
|---|---|---|---|---|---|
| Comum | Lirilì Larilà, Boneca Ambalabu, Trippi Troppi, Chimpanzini Bananini | 50–70 | 40–50% | $1–3/s | 1–5 |
| Raro | Tung Tung Tung Sahur, Brr Brr Patapim, Bombombini Gusini | 120–140 | 25–28% | $8–10/s | 3–8 |
| Épico | Ballerina Cappuccina, Cappuccino Assassino, Frigo Camelo | 250–280 | 12–14% | $25–30/s | 6–12 |
| Lendário | Tralalero Tralala, Bombardiro Crocodilo | 500–550 | 6–7% | $80–90/s | 10–16 |
| Mítico | La Vaca Saturno Saturnita | 1000 | 3% | $250/s | 15–20 |

### Bolas

| Bola | Multiplicador | Preço |
|---|---|---|
| Bola Básica | x1 | $15 |
| Super Bola | x1.75 | $60 |
| Ultra Bola | x2.75 | $200 |
| Bola Suprema | x6 | $1.500 |

**Fórmula:** `chance = chance base × multiplicador da bola × (1 + 2 × (1 − vida/vidaMáxima))`

### Tacos

| Taco | Dano | Preço |
|---|---|---|
| Madeira | 10 | grátis |
| Metal | 22 | $600 |
| Ouro | 45 | $4.000 |
| Diamante | 90 | $20.000 |

> Taco muito forte em brainrot fraco = nocaute! Escolha o taco certo para cada um.

---

## Como colocar no Roblox Studio

O servidor **constrói o mapa sozinho** (chão, zona de caça, árvores e 6 bases), então você só precisa colocar os scripts.

### Jeito mais fácil: abrir o arquivo pronto

1. Baixe o arquivo **`BrainrotTycoon.rbxlx`** (na página do repositório no GitHub, clique nele e depois em
   **Download raw file**).
2. Dê dois cliques nele (ou, no Roblox Studio, **File → Open from File...**).
3. Aperte **Play** (F5).

> Mudou algum script na pasta `src`? Gere o arquivo de novo com `python3 tools/build_place.py`.

### Opção A: com Rojo

1. Instale o [Rojo](https://rojo.space/) (extensão do VS Code ou `aftman`/`rokit`) e o plugin do Rojo no Studio.
2. Nesta pasta, rode `rojo serve`.
3. No Studio, abra o plugin do Rojo e clique em **Connect**.
4. Aperte **Play**.

### Opção B: copiar e colar na mão

Crie os objetos abaixo no Studio (o nome precisa ser **exatamente** igual) e cole o código de cada arquivo:

```
ReplicatedStorage
└── Shared                (Folder)
    ├── Config            (ModuleScript)  ← src/shared/Config.luau
    ├── CatchMath         (ModuleScript)  ← src/shared/CatchMath.luau
    └── Stats             (ModuleScript)  ← src/shared/Stats.luau

ServerScriptService
└── Server                (Folder)
    ├── Main              (Script)        ← src/server/Main.server.luau
    └── Services          (Folder)
        ├── Remotes       (ModuleScript)  ← src/server/Services/Remotes.luau
        ├── DataService   (ModuleScript)  ← src/server/Services/DataService.luau
        ├── BrainrotModels(ModuleScript)  ← src/server/Services/BrainrotModels.luau
        ├── WorldBuilder  (ModuleScript)  ← src/server/Services/WorldBuilder.luau
        ├── WildService   (ModuleScript)  ← src/server/Services/WildService.luau
        ├── TycoonService (ModuleScript)  ← src/server/Services/TycoonService.luau
        ├── CompanionService (ModuleScript) ← src/server/Services/CompanionService.luau
        ├── ToolService   (ModuleScript)  ← src/server/Services/ToolService.luau
        └── ShopService   (ModuleScript)  ← src/server/Services/ShopService.luau

StarterPlayer
└── StarterPlayerScripts
    └── Client            (Folder)
        └── Main          (LocalScript)   ← src/client/Main.client.luau
```

### Configurações importantes no Studio

- **Salvar progresso:** publique o jogo e ative *Game Settings → Security → Enable Studio Access to API Services*.
  Sem isso o jogo funciona, mas não salva.
- **Máximo de jogadores:** o mapa tem **6 bases**, então coloque *Game Settings → Places → Max Players = 6*
  (ou adicione mais bases em `Config.Tycoon.Plots`).

---

## Deixar os brainrots bonitos (modelos 3D da Toolbox)

Sem modelo, cada brainrot é montado com peças simples no formato dele. Para ficar igual ao meme,
use os modelos 3D grátis da Toolbox do Roblox:

1. No Studio: **View → Toolbox**, aba **Models**. Pesquise o nome (ex.: `Tung Tung Tung Sahur`).
2. Clique no modelo para colocar no mapa.
3. No **Explorer**, crie uma pasta chamada **`BrainrotModels`** dentro de **ServerStorage**
   (botão direito em ServerStorage → Insert Object → Folder).
4. Arraste o modelo para dentro dessa pasta e **renomeie** com o `id` da tabela abaixo.
5. Aperte **Play**. O jogo ajusta o tamanho sozinho e usa o modelo nos selvagens, nos pedestais e no parceiro.

| id (nome do modelo) | Brainrot |
|---|---|
| `Lirili` | Lirilì Larilà |
| `Ambalabu` | Boneca Ambalabu |
| `TrippiTroppi` | Trippi Troppi |
| `Chimpanzini` | Chimpanzini Bananini |
| `TungTung` | Tung Tung Tung Sahur |
| `Patapim` | Brr Brr Patapim |
| `Gusini` | Bombombini Gusini |
| `Ballerina` | Ballerina Cappuccina |
| `CappuccinoAssassino` | Cappuccino Assassino |
| `FrigoCamelo` | Frigo Camelo |
| `Tralalero` | Tralalero Tralala |
| `Bombardiro` | Bombardiro Crocodilo |
| `VacaSaturno` | La Vaca Saturno Saturnita |

> ⚠️ **Cuidado com vírus:** modelos da Toolbox podem ter scripts escondidos. O jogo **apaga os scripts** das
> cópias que ele usa, mas mesmo assim, abra o modelo no Explorer e **apague** qualquer `Script`/`LocalScript`
> que tiver dentro. Prefira modelos com muitos likes.
>
> Se o brainrot andar de costas ou de lado, coloque `modelYaw = 180` (ou `90`/`-90`) nele na Config.
> Se ficar grande ou pequeno demais, mude a altura em `size` (o segundo número).

---

## Personalizar

Tudo fica em **`src/shared/Config.luau`**:

- **Novos brainrots:** copie um bloco dentro de `Config.Brainrots` e mude `id`, `name`, cores, vida...
- **Modelos 3D:** veja a seção "Deixar os brainrots bonitos" acima.
- **Seu próprio mapa:** coloque `Config.BuildMap = false` e ajuste `Config.Wild.ZoneCenter` / `ZoneSize`
  para a área onde os brainrots devem andar.
- **Balanceamento:** vida, chance, preços, renda, dano, tempo de regeneração, quantidade de brainrots no mapa.
- **Níveis e evolução:** `Config.Levels` (XP necessário, bônus por nível, níveis de evolução).
- **Ataques:** `Config.Moves` (dano, recarga, alcance, nível para aprender e tecla).
- **Parceiro:** `Config.Companion` (força extra, tempo de desmaio, distância do modo automático).
- **Nomes das evoluções e golpe especial:** campos `evolutions` e `signature` de cada brainrot.

## Estrutura do código

| Arquivo | O que faz |
|---|---|
| `shared/Config` | Todos os números e listas do jogo |
| `shared/CatchMath` | Fórmula de captura (servidor e tela usam a mesma) |
| `shared/Stats` | Vida/força/renda por nível, evoluções, XP e ataques aprendidos |
| `server/Main` | Liga tudo e cuida de entrada/saída de jogadores |
| `DataService` | Salva/carrega dados (DataStore) e o placar (leaderstats) |
| `WorldBuilder` | Constrói o mapa |
| `WildService` | Brainrots selvagens: spawn, IA, vida, ataque, regeneração, desmaio |
| `CompanionService` | Parceiro: seguir, lutar, ataques especiais, desmaio, XP, nível e evolução |
| `ToolService` | Taco (golpe) e Bola (arremesso em arco + tentativa de captura com sacudidas) |
| `TycoonService` | Bases, pedestais, renda passiva e coletor |
| `ShopService` | Loja, vender, colocar/guardar e escolher bola |
| `client/Main` | Interface: dinheiro, bolas, inventário, loja, Brainrotdex, chance na mira e painel do parceiro |
