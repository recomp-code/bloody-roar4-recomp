# Bloody Roar 4 [Analog Stick Mod] — port nativo para PC

[English](README.md) | **Español**

Juega a **Bloody Roar 4** (PS2, PAL **SLES-51877**) con el **Analog Stick Mod** como un programa nativo de
**Windows**: 60 fps, alta resolución, 16:9, NVIDIA DLSS (y el pase neural experimental "DLSS 5") y mando.
El juego se recompila a código x64 nativo con [PS2Recomp](https://github.com/ran-j/PS2Recomp) y se dibuja
en tu GPU con el render de [PCSX2](https://github.com/PCSX2/pcsx2), igual que los ports de
[NBA Street V3](https://github.com/recomp-code/street-recomp-v3) y
[Dragon Ball Z Budokai Tenkaichi 4](https://github.com/recomp-code/dbz-bt4-recomp).

> **Necesitas tu propia copia** de Bloody Roar 4 [Analog Stick Mod] (PAL, SLES-51877) en un archivo ISO.
> No se incluye nada del juego: se compila en tu ordenador a partir de tu copia.

| | |
|---|---|
| ![Pantalla de título](docs/screenshots/title.png) | ![Selección de personaje](docs/screenshots/select.png) |
| ![Pelea, supermuestreo 6x](docs/screenshots/fight1.png) | ![Pelea](docs/screenshots/fight2.png) |
| ![Pelea, 6x](docs/screenshots/fight3.png) | ![DLSS 5, 1920x1080](docs/screenshots/dlss5.png) |

*Capturas del port nativo (RTX 4090): 16:9, resolución interna 6x; la última con DLSS 5 a 1920x1080.*

### Video: una pelea con DLSS 5

<!-- inline-video -->
[▶ Resumen, 30 s (720p60)](docs/videos/br4_dlss5_highlights.mp4)

*Busuzima contra Uriko con todo lo de calidad activado: "DLSS 5" (Direct3D 12, NVIDIA DLSS con el pase neural de
RenoDX encima), 16:9, 60 fps y el sonido del juego. GitHub solo reproduce dentro de la página videos de hasta 10 MB.*
**[▶ Video completo, 2:30 a 2488x1400 60 fps (AV1): pantalla de título, selección de personaje y la pelea entera](docs/videos/br4_dlss5_full.mp4)**

Grabado en el port nativo con `tools\record_video_dlss5.ps1` (la ventana tal como se ve, así que el pase neural
sale en el video, más el audio del runtime con `PS2X_WAVCAP`).

## Estado

Jugable: arranque, memory card (AUTO LOAD), los videos HUDSONCI y OPENING, título, selección de
personaje y peleas, con música (BGM en streaming) y efectos, a velocidad completa. Todavía no se han
recorrido todos los modos: si algo falla, abre un issue.

## Características

- **Nativo en Windows (x64).** El código del juego se recompila a código nativo: no hay emulador de CPU
  mientras juegas.
- **60 fps** en peleas y menús aunque el disco sea PAL (50 Hz): el runtime genera el VBlank a 60 Hz, así
  que el juego corre a la velocidad de la versión NTSC. Los videos van a sus 25 fps.
- **El Analog Stick Mod incluido:** el mando está siempre en modo analógico y el stick izquierdo mueve
  como la cruceta (8 direcciones). En consola había que pulsar ANALOG.
- **Panorámico 16:9** (por defecto), con el parche panorámico de ElHecht para SLES-51877; o el 4:3 original.
- **Tres calidades** en el launcher:
  - **Supermuestreo 6x** (Vulkan, cualquier GPU): resolución interna 6x, anisotrópico 16x, FXAA y nitidez
    CAS. La imagen más nítida.
  - **NVIDIA DLSS** (RTX): resolución interna 2x reescalada por DLSS a tu pantalla (AMD FSR 1 en otras GPU).
  - **DLSS 5** (RTX, experimental): Direct3D 12 + DLSS con el pase neural de NVIDIA encima (DLSS Neural
    Rendering mediante ReShade y el add-on RenoDX DLSS 5, sacados de tu instalación de
    [DLSS 5 Swapper](#dlss-5)). F6 lo enciende y apaga para comparar.
- **Tu propio DLSS:** pon un `nvngx_dlss.dll` más nuevo (o los archivos de DLSS 5) en la carpeta DLSS del
  launcher; el launcher muestra qué versión se usa.
- **Menú gráfico en el juego** (opciones de PCSX2): F1, Back+Start o mantener START.
- **Mando** (tipo Xbox / XInput) y teclado. **Partidas guardadas** normales en una memory card emulada.

## Rendimiento (medido, RTX 4090)

| Calidad | Resolución | Peleas |
|---|---|---|
| Supermuestreo 6x (`br4.ini`, FXAA, CAS, 16:9) | 6x interna (3840x2688) | **59,8–60 fps**, GPU 2–7 ms por frame |
| NVIDIA DLSS (`br4_dlss.ini`) | ventana 2560x1440 (DLSS 640x960 -> 2526x1421) | **59,4–60 fps**, sin tirones |
| DLSS 5 (`br4_dlss_dx12.ini`, pase neural encendido) | 1920x1080 | **57–60 fps** |

## Jugar en Windows

1. Descarga el zip de la release (o clona este repositorio) en **`C:\BloodyRoar4Recomp\bloody-roar4-recomp`**.
   La carpeta del proyecto es `C:\BloodyRoar4Recomp` (con `BR4_ROOT` puedes usar otra).
2. Doble clic en **`Launcher.cmd`**, pulsa **Browse...** y elige tu ISO de **Bloody Roar 4 [Analog Stick Mod]**.
3. Pulsa **Prepare game** (solo una vez: instala las herramientas de C++ si faltan, copia los archivos del
   juego de tu ISO, descarga PS2Recomp, recompila el juego y lo compila, cerca de una hora; la ventana
   muestra el progreso). El render (`pcsx2-gsrunner` de PCSX2) viene ya compilado en el zip de la release;
   desde un clon de git mira [docs/BUILDING.es.md](docs/BUILDING.es.md#el-render).
4. Elige la imagen (**6x supersampling**, **NVIDIA DLSS** o **DLSS 5**), **Widescreen 16:9**,
   **Fullscreen** y si usar **tus propias DLL de DLSS**, y pulsa **PLAY**.

Por defecto: 16:9, pantalla completa, supermuestreo 6x y tus archivos de DLSS si los hay.
**`Play.cmd`** arranca el juego con los ajustes guardados y sin la ventana del launcher; también acepta
opciones para un arranque: `Play.cmd dlss 4:3 window`.

### DLSS 5

"DLSS 5" es el pase neural de DLSS de NVIDIA aplicado encima del DLSS normal, mediante ReShade y el add-on
RenoDX DLSS 5. Ninguno de esos archivos viene aquí. El launcher los toma de tu instalación de **DLSS 5
Swapper** (`%LOCALAPPDATA%\Programs\DLSS 5 Swapper`) o de la **carpeta DLSS** (`C:\BloodyRoar4Recomp\DLSS`,
botón *Add DLSS files...*): `nvngx_dlssnr.dll`, `ReShade64.dll` y `renodx-dlss5.addon64`. Con ellos arma
`C:\BloodyRoar4Recomp\gshost_dlss5`, una copia del render con ReShade como `dxgi.dll`, así el render normal
nunca carga ReShade. Sin esos archivos la calidad DLSS 5 pasa a DLSS normal. En el juego: **F6** = pase
neural sí/no, **Inicio** = menú de ReShade, **F1** = menú gráfico.

## Controles

| | Teclado | Mando (XInput) |
|---|---|---|
| Moverse | Flechas (cruceta) o WASD (stick izquierdo) | Cruceta o **stick izquierdo** |
| Cuadrado, Cruz, Círculo, Triángulo | Z, X, C, V | X, A, B, Y |
| L1, R1, L2, R2 | Q, E, 1, 3 | LB, RB, LT, RT |
| START / SELECT | Enter / Retroceso | Start / Back |
| Menú gráfico | F1 | Back+Start o mantener Start |
| Pantalla completa | Alt+Enter o F11 | |

**Analog Stick Mod:** el mando está siempre en modo analógico y el stick izquierdo también pulsa la cruceta
(8 direcciones: un eje cuenta cuando es al menos la mitad del otro). `PS2X_BR4_STICK=0` lo apaga;
`PS2X_BR4_STICK_DEADZONE=0..127` (48 por defecto) es cuánto hay que mover el stick.

## Cómo funciona

El ELF del juego (`SLES_518.77` del mod) lo traduce a C++ el recompilador de PS2Recomp en tu PC, con la
configuración de este repositorio (`game/config`: la lista de funciones de Ghidra, los stubs de las
bibliotecas SCE y puntos de entrada para código que Ghidra no vio), y se compila junto con el runtime de
PS2Recomp (kernel del EE, IOP, SPU2, CD, MPEG) en `ps2EntryRunner.exe`. Los gráficos de la PS2 viajan por un
anillo de memoria compartida al GS de PCSX2, que corre en su propio proceso (`pcsx2-gsrunner -live`: VIF1,
microVU1, GIF y el GS en Vulkan o Direct3D 12, con DLSS/FSR, la ventana, teclado y mando).

Lo que Bloody Roar 4 necesitó encima del runtime de NBA Street V3 / DBZ (detalles en
[docs/PORTING_NOTES.md](docs/PORTING_NOTES.md)):

- **El gancho del mod en `scePadRead`.** El Analog Stick Mod parchea la copia de `scePadRead` de libpad del
  juego (0x2DA7D0) para saltar a código fuera del ELF (0xFD050 / 0xFD05C) que post-procesa los datos del
  mando. Ese código no se puede recompilar, así que `scePadRead` es el del runtime y el trabajo del mod se
  hace en nativo después (`game/overrides/bloody_roar4_overrides.cpp`).
- **RPC IOP -> EE para el driver de sonido de Hudson.** El SSM de Hudson (en el IOP) hace bind al servidor
  RPC 0x1001 que el juego registra en el EE y le pide los bancos de sonido (el EE responde con
  `sceSifSetDma` al IOP). El runtime ahora atiende servidores RPC del EE para clientes del IOP; el hilo del
  IOP espera a que termine el manejador del EE.
- **`thvpool` del IOP** (pools de memoria de tamaño variable) y heap del IOP desde 0xA0000 (el SSM pide
  512 KB + 2x288 KB); el `sceCdRead` del SSM (música en streaming) se sirve desde la imagen del disco.
- **Orden de PATH3.** Bloody Roar 4 sube ~90 texturas por frame en una sola cadena VIF1: cada ventana
  MSKPATH3 suelta exactamente un paquete GIF de PATH3, enviado dentro del flujo VIF1 como DIRECT, para que
  el VU1 con hilo propio del host no se adelante a las texturas.
- **Videos PSS.** El demuxer guarda el video comprimido en vez de rechazar entrada (el audio va adelantado
  en el flujo y el juego sincroniza las imágenes con la posición del audio), y los bucles de
  `RotateThreadReadyQueue` hacen avanzar el tiempo.
- **Arreglos menores:** formatos de 24 bits en las lecturas del GS (el cuelgue de DBZ al empezar las
  peleas), el malloc propio del juego sobre todo el heap (1 MB reservado al runtime),
  `sceGifPkCloseGifTag` suma el qwc del tag DMA una sola vez, dos copias sin nombre de `sceCdSearchFile`
  enlazadas a la del runtime.
- **16:9:** el pnach panorámico de ElHecht para SLES-51877 reescribe la escala horizontal de la proyección
  en 0x0060EC20 (0x3FDA2E04 -> 0x3FA3A283) en cada `sceGsSyncV`, solo si ahí está el valor original.

## Para desarrolladores

| Ruta | Qué es |
|---|---|
| `Launcher.cmd`, `Launcher.ps1`, `Play.cmd` | Launcher (WinForms, PowerShell 5.1) y arranque rápido con los ajustes guardados |
| `patches/ps2recomp.patch` | Cambios a PS2Recomp `2c5fbb9`: todo lo del port de NBA Street V3 más lo de Bloody Roar 4 (RPC IOP->EE, thvpool, PATH3, PSS, anillo v2) |
| `patches/pcsx2.patch` | Cambios a PCSX2 `d073d75`: el render en vivo de NBA Street V3 (`pcsx2-gsrunner -live`, DLSS/FSR, menú F1) más los cambios del host de DBZ BT4 (anillo v2 con lecturas GS->EE, respuestas ReadFIFO2 en Windows, `PS2X_LIVE_SERIAL` / `PS2X_LIVE_TITLE`, capturas del host) |
| `game/config/` | Configuración del recompilador para SLES_518.77 (sin código del juego: direcciones y nombres) |
| `game/overrides/bloody_roar4_overrides.cpp` | Lo propio del juego: mod analógico, 16:9, imagen del CD, enlaces |
| `gshost/` | Presets del render `br4*.ini` (6x / DLSS, 16:9 / 4:3) y `dlss5/` (preset Direct3D 12, ReShade.ini) |
| `tools/` | `install.ps1` (lo que ejecuta *Prepare game*), `generate_game.ps1`, compilación, Ghidra, pruebas |
| `docs/BUILDING.es.md` | Compilación a mano, el render, rehacer la configuración, regenerar los parches |
| `docs/PORTING_NOTES.md` | Notas técnicas (inglés): todo lo cambiado en el runtime y por qué |

Nunca subas archivos del juego (ISO, ELF, archivos extraídos del disco, código generado, partidas).

## Licencia y créditos

GPL-3.0, como PS2Recomp y PCSX2.

- [PS2Recomp](https://github.com/ran-j/PS2Recomp) de ran-j y colaboradores: el recompilador y el runtime.
- [PCSX2](https://github.com/PCSX2/pcsx2): el render del GS y microVU.
- El [port de NBA Street V3](https://github.com/recomp-code/street-recomp-v3) (runtime, host GS en vivo,
  integración de DLSS, herramientas) y el [port de DBZ BT4](https://github.com/recomp-code/dbz-bt4-recomp)
  (el host GS que usa este port, configuración de DLSS 5), sobre los que está hecho este port.
- **ElHecht** por el parche panorámico de SLES-51877.
- Los autores del **Bloody Roar 4 Analog Stick Mod**.
- DLSS 5 Swapper, RenoDX y ReShade para DLSS 5 (no incluidos; se usan desde tu propia instalación).

Bloody Roar 4 fue desarrollado por Eighting y publicado por Hudson Soft y Konami; es propiedad de sus
dueños. Este proyecto no está afiliado a ellos y no incluye contenido del juego: **usa tu propio disco
original.**
