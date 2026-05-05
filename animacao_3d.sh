#!/usr/bin/env bash

# ==============================================================================
# ANIMACAO 3D ASCII — Motor de Renderização Bash + AWK
# ==============================================================================
# Bash: loop de input e temporização. AWK: co-processo persistente que mantém
# estado (ângulos, velocidade, forma) e renderiza direto no terminal via FIFO.
#
# Formas disponíveis (Space/f para ciclar):
#   0 - Toróide   1 - Esfera   2 - Cilindro   3 - Cone   4 - Cubo
# ==============================================================================

export LC_NUMERIC=C

fps=24
sleep_time=$(awk "BEGIN { printf \"%.4f\", 1/$fps }")

declare -A PALETAS=(
  [azul]="23 25 27 33 39 45 51 81 123 159 195 231"
  [verde]="22 28 34 40 46 82 118 154 190 226 227 231"
  [fogo]="52 88 124 160 196 202 208 214 220 226 227 231"
  [roxo]="17 18 54 90 126 162 163 164 165 171 177 231"
)
paleta_nomes=(azul verde fogo roxo)
paleta_idx=0

FIFO=$(mktemp -u /tmp/asc_XXXXXX)
mkfifo "$FIFO"

cleanup() {
  exec 3>&- 2>/dev/null
  rm -f "$FIFO"
  stty echo icanon 2>/dev/null || true
  tput cnorm 2>/dev/null || true
  printf '\033[0m\033[2J\033[H'
}
trap cleanup EXIT INT TERM

# --- Co-processo AWK (renderer persistente) -----------------------------------
awk '
  # Escreve um pixel no Z-buffer e screen[]
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

  # Projeta ponto 3D (x0,y0,z0) com normal (nx,ny,nz) → pixel na tela.
  # Usa rotação dupla (A=vertical, B=horizontal) + perspectiva.
  # ssx/ssy: escala de projeção para X e Y (ajuste por forma).
  function draw_pt(x0, y0, z0, nx, ny, nz,    D, tt, sx, sy, N) {
    D  = 1 / (z0*sA + y0*cA + 5)
    tt = z0*cA - y0*sA
    sx = int(cx + ssx * D * (x0*cB - tt*sB))
    sy = int(cy + ssy * D * (x0*sB + tt*cB))
    N  = int(8 * ((nz*sA+ny*cA)*cB + (nz*cA-ny*sA)*sB + nx*cB))
    put(sx, sy, D, N)
  }

  function render(    j, i, ct, st, sp, cp, h, D, tt, x, y, N, r, ci, si, u, v, row, col, k, line) {
    delete zbuf; delete screen
    cx = int(W/2); cy = int(H/2)
    cA=cos(a); sA=sin(a); cB=cos(b); sB=sin(b)

    if (shape == 0) {
      # ── Toróide ─────────────────────────────────────────────────────────────
      # Mantém fórmula original (normal específica do toro)
      ssx=W*0.28; ssy=H*0.65
      for (j=0; j<6.28318; j+=0.15) { ct=cos(j); st=sin(j)
        for (i=0; i<6.28318; i+=0.06) { sp=sin(i); cp=cos(i)
          h=ct+2; D=1/(sp*h*sA+st*cA+5); tt=sp*h*cA-st*sA
          x=int(cx+(W*0.28)*D*(cp*h*cB-tt*sB))
          y=int(cy+(H*0.65)*D*(cp*h*sB+tt*cB))
          N=int(8*((st*sA-sp*ct*cA)*cB-sp*ct*sA-st*cA-cp*ct*sB))
          put(x, y, D, N)
        }
      }

    } else if (shape == 1) {
      # ── Esfera ───────────────────────────────────────────────────────────────
      # Normal = próprio ponto (superfície unitária)
      ssx=W*0.35; ssy=H*0.80
      for (j=0; j<3.14159; j+=0.12) { ct=cos(j); st=sin(j)
        for (i=0; i<6.28318; i+=0.06) { sp=sin(i); cp=cos(i)
          D=1/(sp*st*sA+ct*cA+5); tt=sp*st*cA-ct*sA
          x=int(cx+(W*0.35)*D*(cp*st*cB-tt*sB))
          y=int(cy+(H*0.80)*D*(cp*st*sB+tt*cB))
          N=int(10*((st*sp*sA+ct*cA)*cB+(st*sp*cA-ct*sA)*sB+cp*st*cB))
          put(x, y, D, N)
        }
      }

    } else if (shape == 2) {
      # ── Cilindro ─────────────────────────────────────────────────────────────
      # Superfície lateral: normal radial (cos θ, 0, sin θ)
      # Tampas: normal axial (0, ±1, 0)
      ssx=W*0.30; ssy=H*0.75
      for (j=-1; j<=1.001; j+=0.06) {
        for (i=0; i<6.28318; i+=0.06) {
          ci=cos(i); si=sin(i)
          draw_pt(ci, j, si,  ci, 0, si)
        }
      }
      for (r=0; r<=1.001; r+=0.06) {
        for (i=0; i<6.28318; i+=0.08) {
          ci=cos(i); si=sin(i)
          draw_pt(r*ci,  1, r*si,  0,  1, 0)
          draw_pt(r*ci, -1, r*si,  0, -1, 0)
        }
      }

    } else if (shape == 3) {
      # ── Cone ─────────────────────────────────────────────────────────────────
      # Parâmetro t: 0 = ápice (topo), 1 = base
      # Normal lateral: inclinada 45° → (cos θ, 1, sin θ) / √2
      # Tampa da base: normal (0, -1, 0)
      ssx=W*0.30; ssy=H*0.75
      for (j=0; j<=1.001; j+=0.04) {
        for (i=0; i<6.28318; i+=0.06) {
          ci=cos(i); si=sin(i)
          draw_pt(j*ci, 1-2*j, j*si,  ci*0.7071, 0.7071, si*0.7071)
        }
      }
      for (r=0; r<=1.001; r+=0.06) {
        for (i=0; i<6.28318; i+=0.08) {
          draw_pt(r*cos(i), -1, r*sin(i),  0, -1, 0)
        }
      }

    } else if (shape == 4) {
      # ── Cubo ─────────────────────────────────────────────────────────────────
      # 6 faces amostradas em grade, cada uma com normal constante.
      # Sombreamento flat por face: face visível = caracteres claros, oculta = escuros.
      ssx=W*0.28; ssy=H*0.65
      for (u=-1; u<=1.001; u+=0.1) {
        for (v=-1; v<=1.001; v+=0.1) {
          draw_pt( 1, u, v,   1,  0,  0)
          draw_pt(-1, u, v,  -1,  0,  0)
          draw_pt(u,  1, v,   0,  1,  0)
          draw_pt(u, -1, v,   0, -1,  0)
          draw_pt(u, v,  1,   0,  0,  1)
          draw_pt(u, v, -1,   0,  0, -1)
        }
      }
    }

    # ── Renderiza frame + barra de status ────────────────────────────────────
    printf "\033[H"
    for (row=0; row<H; row++) {
      line=""
      for (col=0; col<W; col++) {
        k = row SUBSEP col
        line = line (k in screen ? screen[k] : (cmode==1 ? " " : "\033[0m "))
      }
      print line (cmode==1 ? "" : "\033[0m")
    }
    printf "\033[0;7m [Space] %-9s [C]or  [P]aleta  [↑↓] vel  [Q]uit \033[0m\n", shapes[shape]
    fflush()
  }

  BEGIN {
    chars = ".,-~:;=!*#$@"
    speed = 1; a = 0; b = 0; base_va = 0.07; base_vb = 0.03
    shape = 0; cmode = 0; W = 79; H = 23
    split("23 25 27 33 39 45 51 81 123 159 195 231", colors, " ")
    shapes[0]="Toroide"; shapes[1]="Esfera"; shapes[2]="Cilindro"
    shapes[3]="Cone";    shapes[4]="Cubo"

    while ((getline cmd) > 0) {
      if      (cmd == "TICK")       { a+=base_va*speed; b+=base_vb*speed; render() }
      else if (cmd == "SPEED_UP")   { speed = (speed+0.2 > 4   ? 4   : speed+0.2) }
      else if (cmd == "SPEED_DOWN") { speed = (speed-0.2 < 0.2 ? 0.2 : speed-0.2) }
      else if (cmd == "SHAPE")      { shape = (shape+1) % 5 }
      else if (cmd == "COLOR")      { cmode = (cmode+1) % 3 }
      else if (cmd ~ /^SIZE /)      { split(substr(cmd,6), sz, " "); W=sz[1]; H=sz[2] }
      else if (cmd ~ /^PALETTE /)   { split(substr(cmd,9), colors, " ") }
    }
  }
' < "$FIFO" &

exec 3>"$FIFO"

stty -echo -icanon time 0 min 0 2>/dev/null || true
tput civis 2>/dev/null || true
printf '\033[2J\033[H'

printf 'PALETTE %s\n' "${PALETAS[azul]}" >&3

while :; do
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

  read rows cols < <(stty size 2>/dev/null || echo "24 80")
  printf 'SIZE %d %d\n' "$((cols-1))" "$((rows-2))" >&3
  printf 'TICK\n' >&3

  sleep "$sleep_time"
done
