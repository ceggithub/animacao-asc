#!/usr/bin/env bash

# ==============================================================================
# ANIMACAO 3D ASCII — Motor de Renderização Bash + AWK
# ==============================================================================
# Renderiza Toróide e Esfera em ASCII com iluminação e Z-buffer no terminal.
#
# Arquitetura:
#   - Bash: loop principal, captura de input, envio de comandos via FIFO
#   - AWK:  co-processo persistente — elimina fork/exec por frame, mantém
#           estado interno (ângulos, velocidade) e renderiza direto no terminal
# ==============================================================================

export LC_NUMERIC=C

fps=24
sleep_time=$(awk "BEGIN { printf \"%.4f\", 1/$fps }")

# --- Paletas de cor ANSI 256 (12 níveis de luminância cada) -------------------
declare -A PALETAS=(
  [azul]="23 25 27 33 39 45 51 81 123 159 195 231"
  [verde]="22 28 34 40 46 82 118 154 190 226 227 231"
  [fogo]="52 88 124 160 196 202 208 214 220 226 227 231"
  [roxo]="17 18 54 90 126 162 163 164 165 171 177 231"
)
paleta_nomes=(azul verde fogo roxo)
paleta_idx=0

# --- FIFO para comunicação com o co-processo AWK ------------------------------
FIFO=$(mktemp -u /tmp/asc_XXXXXX)
mkfifo "$FIFO"

cleanup() {
  exec 3>&- 2>/dev/null   # fecha write end → AWK recebe EOF e termina
  rm -f "$FIFO"
  stty echo icanon 2>/dev/null || true
  tput cnorm 2>/dev/null || true
  printf '\033[0m\033[2J\033[H'
}
trap cleanup EXIT INT TERM

# --- Co-processo AWK (renderer persistente) -----------------------------------
# Lê comandos linha a linha do FIFO, mantém estado interno, escreve no terminal.
# Comandos aceitos: TICK | SPEED_UP | SPEED_DOWN | SHAPE | COLOR |
#                   SIZE <w> <h> | PALETTE <c0>..<c11>
awk '
  function put(x, y, d, n,    key, ch, pfx) {
    if (x<0 || x>=W || y<0 || y>=H) return
    key = y SUBSEP x
    if (!(key in zbuf) || d > zbuf[key]) {
      zbuf[key] = d
      if (n < 0) n = 0
      if (n > 11) n = 11
      ch = substr(chars, n+1, 1)
      if      (cmode == 0) pfx = "\033[38;5;" colors[n+1] "m"
      else if (cmode == 1) pfx = ""
      else                 pfx = "\033[38;5;34m"
      screen[key] = pfx ch
    }
  }

  function render(    cx,cy,cA,sA,cB,sB,j,i,ct,st,sp,cp,h,D,t,x,y,N,row,col,k,line) {
    delete zbuf; delete screen
    cx = int(W/2); cy = int(H/2)
    cA=cos(a); sA=sin(a); cB=cos(b); sB=sin(b)

    if (shape == 0) {
      for (j=0; j<6.28318; j+=0.15) { ct=cos(j); st=sin(j)
        for (i=0; i<6.28318; i+=0.06) { sp=sin(i); cp=cos(i)
          h=ct+2; D=1/(sp*h*sA+st*cA+5); t=sp*h*cA-st*sA
          x=int(cx+(W*0.28)*D*(cp*h*cB-t*sB))
          y=int(cy+(H*0.65)*D*(cp*h*sB+t*cB))
          N=int(8*((st*sA-sp*ct*cA)*cB-sp*ct*sA-st*cA-cp*ct*sB))
          put(x, y, D, N)
        }
      }
    } else {
      for (j=0; j<3.14159; j+=0.12) { ct=cos(j); st=sin(j)
        for (i=0; i<6.28318; i+=0.06) { sp=sin(i); cp=cos(i)
          D=1/(sp*st*sA+ct*cA+5); t=sp*st*cA-ct*sA
          x=int(cx+(W*0.35)*D*(cp*st*cB-t*sB))
          y=int(cy+(H*0.8)*D*(cp*st*sB+t*cB))
          N=int(10*((st*sp*sA+ct*cA)*cB+(st*sp*cA-ct*sA)*sB+cp*st*cB))
          put(x, y, D, N)
        }
      }
    }

    printf "\033[H"
    for (row=0; row<H; row++) {
      line=""
      for (col=0; col<W; col++) {
        k = row SUBSEP col
        line = line (k in screen ? screen[k] : (cmode==1 ? " " : "\033[0m "))
      }
      print line (cmode==1 ? "" : "\033[0m")
    }
    fflush()
  }

  BEGIN {
    chars = ".,-~:;=!*#$@"
    speed = 1; a = 0; b = 0; base_va = 0.07; base_vb = 0.03
    shape = 0; cmode = 0; W = 79; H = 23
    split("23 25 27 33 39 45 51 81 123 159 195 231", colors, " ")

    while ((getline cmd) > 0) {
      if      (cmd == "TICK")       { a+=base_va*speed; b+=base_vb*speed; render() }
      else if (cmd == "SPEED_UP")   { speed = (speed+0.2 > 4   ? 4   : speed+0.2) }
      else if (cmd == "SPEED_DOWN") { speed = (speed-0.2 < 0.2 ? 0.2 : speed-0.2) }
      else if (cmd == "SHAPE")      { shape = (shape+1) % 2 }
      else if (cmd == "COLOR")      { cmode = (cmode+1) % 3 }
      else if (cmd ~ /^SIZE /)      { split(substr(cmd,6), sz, " "); W=sz[1]; H=sz[2] }
      else if (cmd ~ /^PALETTE /)   { split(substr(cmd,9), colors, " ") }
    }
  }
' < "$FIFO" &

# Abre o write end do FIFO e mantém aberto (fd 3) durante toda a execução.
# Isso evita que o AWK receba EOF prematuro entre frames.
exec 3>"$FIFO"

stty -echo -icanon time 0 min 0 2>/dev/null || true
tput civis 2>/dev/null || true
printf '\033[2J\033[H'

# Envia paleta inicial ao co-processo
printf 'PALETTE %s\n' "${PALETAS[azul]}" >&3

while :; do
  # --- Captura de input (não-bloqueante) --------------------------------------
  while IFS= read -rsn1 -t 0.001 key; do
    if [[ $key == $'\e' ]]; then
      read -rsn1 -t 0.001 k2 || true
      read -rsn1 -t 0.001 k3 || true
      if [[ ${k2:-} == '[' ]]; then
        case ${k3:-} in
          A) printf 'SPEED_UP\n'   >&3 ;;
          B) printf 'SPEED_DOWN\n' >&3 ;;
        esac
      fi
    elif [[ $key == 'f' || $key == ' ' ]]; then
      printf 'SHAPE\n' >&3
    elif [[ $key == 'c' ]]; then
      printf 'COLOR\n' >&3
    elif [[ $key == 'p' ]]; then
      paleta_idx=$(( (paleta_idx + 1) % ${#paleta_nomes[@]} ))
      printf 'PALETTE %s\n' "${PALETAS[${paleta_nomes[$paleta_idx]}]}" >&3
    elif [[ $key == 'q' ]]; then
      exit 0
    fi
  done

  # --- Envia dimensões atuais e dispara frame ---------------------------------
  read rows cols < <(stty size 2>/dev/null || echo "24 80")
  printf 'SIZE %d %d\n' "$((cols-1))" "$((rows-1))" >&3
  printf 'TICK\n' >&3

  sleep "$sleep_time"
done
