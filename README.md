# Motor de Animação 3D ASCII

Motor de renderização 3D minimalista escrito em Bash + AWK. Renderiza formas geométricas diretamente no terminal usando caracteres ASCII com iluminação, Z-buffer e cores ANSI 256.

## Demonstração

```
         $$$$$$$
      $$$$$$$$$$$$$
    $$$$$$!!!!*####$$$
   $$$$$!!!!!**####$$$$$
  $$$$!!!!***##########$
  $$$!!!****##==========
  $$!!!***##==~~--------
  $$$!!**##=~~-,,,......
   $$!!*##=~-,,.......
    $$$*#=~-,,.  .
      $$=~-,.
```

## Funcionalidades

- **Renderização 3D suave**: toda a matemática pesada executada pelo AWK
- **5 formas geométricas**: Toróide, Esfera, Cilindro, Cone e Cubo — cicláveis em tempo real
- **4 paletas de cor**: Azul, Verde, Fogo e Roxo — cicláveis em tempo real
- **3 modos de cor**: Multicolor, Monocromático e Fósforo Verde
- **Controles em tempo real**: velocidade, forma e cor sem pausar a animação
- **Barra de status**: exibe a forma atual e atalhos de teclado na última linha
- **Responsivo**: adapta o frame ao tamanho atual do terminal a cada ciclo

## Requisitos

- `bash` 4.0+
- `awk` (compatível com gawk, mawk e nawk)
- Terminal com suporte a códigos ANSI e cores de 256

## Como executar

```bash
chmod +x animacao_3d.sh
./animacao_3d.sh
```

## Controles

| Tecla | Ação |
|---|---|
| `Seta Cima` | Aumenta velocidade de rotação |
| `Seta Baixo` | Diminui velocidade de rotação |
| `Espaço` / `f` | Cicla entre as 5 formas (Toróide → Esfera → Cilindro → Cone → Cubo) |
| `c` | Cicla entre os modos de cor (Multicolor → Monocromático → Fósforo Verde) |
| `p` | Cicla entre as paletas de cor (Azul → Verde → Fogo → Roxo) |
| `q` | Encerra e restaura o terminal |

## Paletas disponíveis

| Paleta | Tons |
|---|---|
| Azul | Gradiente do azul escuro ao branco — padrão |
| Verde | Gradiente do verde escuro ao amarelo |
| Fogo | Gradiente do vermelho ao amarelo |
| Roxo | Gradiente do índigo ao branco |

Cada paleta mapeia 12 tons aos 12 níveis de luminância da superfície renderizada.

## Formas disponíveis

| # | Forma | Geometria | Normal de superfície |
|---|---|---|---|
| 0 | Toróide | Loop duplo paramétrico sobre tubo e anel | Radial ao tubo |
| 1 | Esfera | Coordenadas esféricas (φ, θ) | Igual ao ponto (esfera unitária) |
| 2 | Cilindro | Lateral + tampas planas | Radial (lateral) / axial (tampas) |
| 3 | Cone | Ápice em y=1, base em y=-1 + tampa | Inclinada 45° (lateral) / axial (base) |
| 4 | Cubo | 6 faces amostradas em grade | Constante por face (flat shading) |

## Arquitetura

O script é dividido em duas partes com responsabilidades claras:

**Loop Bash (controle e I/O)**
- Captura input do teclado em modo não-bloqueante (`stty -icanon`)
- Lê dimensões do terminal a cada frame (`stty size`)
- Envia comandos ao co-processo AWK via FIFO nomeado

**Co-processo AWK (renderizador persistente)**
- Executa em background durante toda a sessão — elimina o custo de fork/exec por frame
- Mantém estado interno: ângulos de rotação, velocidade, forma, modo de cor e paleta
- Recebe comandos por linha via FIFO: `TICK`, `SPEED_UP`, `SHAPE`, `PALETTE ...`, etc.
- Executa a matemática de renderização e escreve o frame direto no terminal

```
Bash ──[FIFO]──▶ AWK (persistente)
  TICK                 ↓
  SIZE w h         render() → terminal
  PALETTE c0..c11
  SHAPE / COLOR
  SPEED_UP / DOWN
```

### Técnicas de renderização

| Técnica | Implementação |
|---|---|
| Geometria paramétrica | Equações de toróide e esfera com dupla rotação (ângulos A e B) |
| Z-buffer | Array associativo `zbuf[y,x]` — mantém apenas o ponto mais próximo por pixel |
| Iluminação | Normal da superfície mapeada para 12 níveis → charset `.,-~:;=!*#$@` |
| Cor por profundidade | Nível de luminância indexa a paleta ativa (ANSI 256) |
| Cleanup de terminal | `trap` garante restauração do cursor e estado mesmo em Ctrl+C |
