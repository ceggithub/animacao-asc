#!/usr/bin/env bash

# ==============================================================================
# ANIMACAO 3D ASCII - Donut & Esfera
# ==============================================================================
# Um motor de renderização 3D minimalista escrito em Bash e AWK.
# Utiliza projeção matemática para transformar coordenadas 3D em caracteres 2D.
# ==============================================================================

# Força o uso de ponto como separador decimal para compatibilidade internacional
export LC_NUMERIC=C

# Configurações de Frame e Física
fps=24
sleep_time=$(awk "BEGIN { printf \"%.4f\", 1/$fps }")
speed=1.00
angle_a=0.0
angle_b=0.0
base_va=0.070
base_vb=0.030
shape=0       # 0=Toróide (Rosquinha), 1=Esfera
color_mode=0  # 0=Multicolor, 1=Monocromático, 2=Fósforo Verde

# Restaura o estado original do terminal ao sair
cleanup() {
  stty echo icanon 2>/dev/null || true
  tput cnorm 2>/dev/null || true
  printf '\033[0m\033[2J\033[H'
}

trap cleanup EXIT INT TERM

# Configura terminal: oculta cursor, desativa eco e limpa tela
stty -echo -icanon time 0 min 0 2>/dev/null || true
tput civis 2>/dev/null || true
printf '\033[2J\033[H'

# Gradients de cores ANSI 256 para efeito de profundidade/sombra
COLORS="23 25 27 33 39 45 51 81 123 159 195 231"

while :; do
  # Loop de captura de entrada (Teclas de Controle)
  while IFS= read -rsn1 -t 0.001 key; do
    if [[ $key == $'\e' ]]; then
      read -rsn1 -t 0.001 k2 || true
      read -rsn1 -t 0.001 k3 || true
      if [[ ${k2:-} == '[' ]]; then
        case ${k3:-} in
          A) speed=$(awk "BEGIN { s=$speed+0.2; print (s>4?4:s) }") ;; # Seta Cima
          B) speed=$(awk "BEGIN { s=$speed-0.2; print (s<0.2?0.2:s) }") ;; # Seta Baixo
        esac
      fi
    elif [[ $key == 'f' || $key == ' ' ]]; then
      shape=$(( (shape + 1) % 2 )) # Alterna Forma
    elif [[ $key == 'c' ]]; then
      color_mode=$(( (color_mode + 1) % 3 )) # Alterna Cor
    elif [[ $key == 'q' ]]; then
      exit 0 # Sair
    fi
  done

  # Obtém dimensões dinâmicas do terminal
  cols=$(tput cols 2>/dev/null || echo 80)
  rows=$(tput lines 2>/dev/null || echo 24)
  
  # Atualiza ângulos de rotação baseado na velocidade
  angle_a=$(awk "BEGIN { printf \"%.6f\", $angle_a + $base_va * $speed }")
  angle_b=$(awk "BEGIN { printf \"%.6f\", $angle_b + $base_vb * $speed }")

  # Renderização via AWK (Matemática Pesada)
  awk \
    -v width="$((cols - 1))" \
    -v height="$((rows - 1))" \
    -v a="$angle_a" \
    -v b="$angle_b" \
    -v shape="$shape" \
    -v cmode="$color_mode" \
    -v colors_str="$COLORS" '
    
    # Função para projetar ponto no buffer de tela com Z-Buffer (profundidade)
    function put(x, y, d, n,   key, ch, color_prefix) {
      if (x >= 0 && x < width && y >= 0 && y < height) {
        key = y SUBSEP x
        if (!(key in zbuf) || d > zbuf[key]) {
          zbuf[key] = d
          if (n < 0) { n = 0 }
          if (n > 11) { n = 11 }
          ch = substr(chars, n + 1, 1)
          
          if (cmode == 0)      color_prefix = "\033[38;5;" colors[n+1] "m"
          else if (cmode == 1) color_prefix = ""
          else if (cmode == 2) color_prefix = "\033[38;5;34m"
          
          screen[key] = color_prefix ch
        }
      }
    }

    BEGIN {
      chars = ".,-~:;=!*#$@"
      split(colors_str, colors, " ")
      if (width < 10) width = 10; if (height < 5) height = 5
      cx = int(width / 2); cy = int(height / 2)
      cA = cos(a); sA = sin(a); cB = cos(b); sB = sin(b)

      if (shape == 0) {
        # Geometria do Toróide (Donut)
        for (j = 0; j < 6.28; j += 0.15) {
          ct = cos(j); st = sin(j)
          for (i = 0; i < 6.28; i += 0.06) {
            sp = sin(i); cp = cos(i)
            h = ct + 2.0
            D = 1.0 / (sp * h * sA + st * cA + 5.0)
            t = sp * h * cA - st * sA
            x = int(cx + (width * 0.28) * D * (cp * h * cB - t * sB))
            y = int(cy + (height * 0.65) * D * (cp * h * sB + t * cB))
            N = int(8 * ((st * sA - sp * ct * cA) * cB - sp * ct * sA - st * cA - cp * ct * sB))
            put(x, y, D, N)
          }
        }
      } else {
        # Geometria da Esfera
        for (j = 0; j < 3.14; j += 0.12) {
          ct = cos(j); st = sin(j)
          for (i = 0; i < 6.28; i += 0.06) {
            sp = sin(i); cp = cos(i)
            D = 1.0 / (sp * st * sA + ct * cA + 5.0)
            t = sp * st * cA - ct * sA
            x = int(cx + (width * 0.35) * D * (cp * st * cB - t * sB))
            y = int(cy + (height * 0.8) * D * (cp * st * sB + t * cB))
            N = int(10 * ( (st*sp*sA + ct*cA)*cB + (st*sp*cA - ct*sA)*sB + cp*st*cB ))
            put(x, y, D, N)
          }
        }
      }

      # Desenha frame a partir do buffer
      printf "\033[H"
      for (y = 0; y < height; y++) {
        line = ""
        for (x = 0; x < width; x++) {
          k = y SUBSEP x
          if (k in screen) line = line screen[k]
          else line = line (cmode == 1 ? " " : "\033[0m ")
        }
        print line (cmode == 1 ? "" : "\033[0m")
      }
    }
  '
  sleep "$sleep_time"
done
