# Compilar a mano (Windows) y detalles técnicos

[English](BUILDING.md) | **Español**

Para jugar solo hace falta el launcher: mira el [README](../README.es.md). Esta página recoge la compilación a
mano, el render, cómo se hizo la configuración del recompilador, los parches y las herramientas de prueba.

## Requisitos

- Windows 10/11 x64, una GPU con Vulkan (Direct3D 12 para DLSS 5), ~25 GB libres, 16 GB de RAM recomendados.
- **Visual Studio 2022 Build Tools** con "Desarrollo para el escritorio con C++" (MSVC v143 + Windows SDK).
- La carpeta del proyecto es **`C:\BloodyRoar4Recomp`**; con la variable de entorno `BR4_ROOT` se usa otra
  (todos los scripts y el launcher la leen). Este repositorio va en `<proyecto>\bloody-roar4-recomp`.
- Herramientas portables en `C:\BloodyRoar4Recomp\tools\`. Cada una se busca también en
  `C:\NBAStreetRecomp\tools\` (el port de NBA Street V3 usa las mismas versiones): un PC que ya compiló ese
  port no necesita nada nuevo. `tools\env.ps1` / `tools\env.cmd` las encuentran.

| Carpeta | Herramienta | Para |
|---|---|---|
| `tools\mingit\` | [MinGit](https://github.com/git-for-windows/git/releases) (o Git en el PATH) | todo |
| `tools\cmake\cmake-4.4.4-windows-x86_64\` | [CMake 4.x](https://cmake.org/download/) (zip) | todo |
| `tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\` | [LLVM 20](https://github.com/llvm/llvm-project/releases) (clang-cl) | compilar el render |
| `tools\ninja\` | [Ninja](https://github.com/ninja-build/ninja/releases) | compilar el render |
| `tools\python\` | Python 3 embebible | dependencias del render |
| `tools\portablegit\` | [PortableGit](https://github.com/git-for-windows/git/releases) (`bash`, `patch`) | dependencias del render |
| `tools\7zip\` | [7-Zip](https://www.7-zip.org/) extra (`x64\7za.exe`) | dependencias del render |
| `tools\jdk\jdk-21.0.12.1+1\`, `tools\ghidra\ghidra_12.1.4_PUBLIC\` | JDK 21, [Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases) | solo para rehacer la configuración |

*Prepare game* (`tools\install.ps1`) descarga CMake y MinGit por su cuenta si faltan.

## Carpetas

```
C:\BloodyRoar4Recomp\
  bloody-roar4-recomp\    este repositorio (o el zip de la release)
  game\BloodyRoar4.iso    tu ISO (enlace fijo si está en la misma unidad; si no, una copia)
  game\iso\               los archivos del disco (SLES_518.77, SYSTEM.CNF, MODULES, FPACK, STR...); partidas en game\iso\mc0
  game\config, overrides  copias de game\ de este repositorio (config.toml con las rutas de esta carpeta)
  game\output\            el C++ generado desde tu ELF (nunca se sube)
  PS2Recomp\              ran-j/PS2Recomp 2c5fbb9 + patches\ps2recomp.patch; compilación en PS2Recomp\out\build
  pcsx2\, ext\DLSS\       PCSX2 d073d75 + patches\pcsx2.patch y el SDK de DLSS de NVIDIA (solo para compilar el render)
  gshost\                 el render: pcsx2-gsrunner.exe, DLL, resources, nvngx_dlss.dll, br4*.ini
  gshost_dlss5\           lo arma el launcher para DLSS 5 (gshost\ + ReShade como dxgi.dll + RenoDX + DLSSNR)
  DLSS\                   tus propios archivos de DLSS (opcional)
  tools\, logs\
```

## Compilar

**1. Tu juego.** Extrae la ISO y deja la imagen al lado (el juego también lee sectores del disco):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\iso_extract.ps1 -Iso "D:\BR4 Analog.iso" -Out C:\BloodyRoar4Recomp\game\iso
mklink /H C:\BloodyRoar4Recomp\game\BloodyRoar4.iso "D:\BR4 Analog.iso"     (o cópiala)
```
`game\iso\SLES_518.77` debe tener SHA-256 `228548DAB8E4EFD03316C643F39210498691C24C9C39D65DF7715A74BF83DCDB`
(la versión con el Analog Stick Mod): la lista de funciones de `game\config` se hizo con ese archivo exacto.

**2. Fuentes de PS2Recomp con el parche:**
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_sources.ps1
```

**3. Compilar el recompilador:**
```bat
bloody-roar4-recomp\tools\configure.cmd
bloody-roar4-recomp\tools\build_recomp.cmd
```
`configure.cmd`: Visual Studio 2022 x64, sin studio/tests/analizador, compilación unity del código del juego,
sin ventana de consola. Si existe la carpeta de compilación del port de NBA Street V3, reutiliza sus
dependencias ya descargadas.

**4. Generar el código del juego** desde tu ELF (unos minutos):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\generate_game.ps1
```
Copia `game\config` (reescribiendo las rutas para `BR4_ROOT`), ejecuta `ps2_recomp`, copia los `.cpp` a
`PS2Recomp\ps2xRuntime\src\runner` y las cabeceras a `ps2xRuntime\include`, aplica los arreglos sobre el código
generado (`fix_sqrt_s.ps1`, `fix_branch64.ps1`, `fix_cop0_count.ps1`) y añade el override del juego.

**5. Compilar el juego** (lento la primera vez: es todo el juego en C++):
```bat
bloody-roar4-recomp\tools\build_runner.cmd 8
```
El número es cuántos compiladores van a la vez: uno por cada ~2,5 GB de RAM. Resultado:
`PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe`. Los logs van a `logs\`.

**6. El render:** más abajo.

**7. Jugar:** `bloody-roar4-recomp\Launcher.cmd` o `Play.cmd`.
`powershell -File bloody-roar4-recomp\Launcher.ps1 -DryRun [dlss|dlss5] [4:3] [window]` muestra el entorno y
la línea de comandos que usaría PLAY, sin arrancar ni cambiar nada.

## El render

El host del GS es `pcsx2-gsrunner` de PCSX2 compilado desde PCSX2 **`d073d75`** + `patches\pcsx2.patch`: el
render en vivo de NBA Street V3 más los cambios del host de DBZ BT4. Es el mismo `pcsx2-gsrunner.exe` que el
del port de DBZ BT4. `tools\install.ps1` lo toma, por este orden, de:

1. `gshost-win64*.zip` junto al launcher (lo trae el zip de la release; lo hace `tools\make_release.ps1`);
2. `-GsHostDir <carpeta>` (cualquier carpeta con esa compilación, p. ej. `C:\DBZBT4Recomp\gshost`;
   `tools\setup_gshost.ps1 -From <carpeta>` hace lo mismo a mano);
3. `C:\DBZBT4Recomp\gshost` del port de DBZ BT4, si está;
4. `-GsHostUrl <url del zip>`;
5. compilarlo desde el código (`-BuildPcsx2`, o si no hay nada de lo anterior):
   ```bat
   powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_sources.ps1 -WithPcsx2
   bloody-roar4-recomp\tools\build_pcsx2_deps.bat
   bloody-roar4-recomp\tools\build_pcsx2.cmd
   powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_gshost.ps1
   ```
   `-WithPcsx2` también clona el SDK de DLSS de NVIDIA en `ext\DLSS` (cabeceras y biblioteca; sin él el host
   solo tiene AMD FSR). Las dependencias (SDL3, shaderc...) se compilan una vez; si existe
   `C:\NBAStreetRecomp\pcsx2\deps` del port de NBA Street V3, se reutiliza.

Los resources salen del `bin\resources` del propio PCSX2 (entrada original de SLES-51877 en el GameIndex). El
runtime de DLSS de NVIDIA (`nvngx_dlss.dll`) se descarga del repositorio de DLSS de NVIDIA a `gshost\`, con una
copia `nvngx_dlss.orig.dll` que el launcher vuelve a poner cuando *Use my own DLSS DLLs* está apagado.

Presets gráficos (`gshost\br4*.ini`, copiados de este repositorio solo si faltan; F1 en el juego guarda en ellos):

| Archivo | Imagen |
|---|---|
| `br4.ini` / `br4_4x3.ini` | Vulkan, 6x (3840x2688 en PAL), anisotrópico 16x, FXAA, CAS 50, DLSS/FSR cuando la ventana es mayor que la imagen, texturas HD activadas |
| `br4_dlss.ini` / `br4_dlss_4x3.ini` | lo mismo a 2x (1280x1024 en PAL), reescalado por DLSS (FSR 1 sin DLSS) |
| `dlss5\br4_dlss_dx12.ini` | Direct3D 12, 2x + DLSS; el pase neural encima (en `gshost_dlss5\`) |
| `dlss5\ReShade.ini` | ajustes de ReShade + RenoDX DLSS 5: F6 pase neural sí/no, Inicio menú de ReShade |

`NbaUpscaler` (0 = no, 1 = AMD FSR 1, 2 = NVIDIA DLSS) solo actúa mientras la resolución interna es menor que la
ventana: DLSS necesita los presets 2x y una ventana mayor que 1280x1024.

## Rehacer la configuración del recompilador

No hace falta para compilar: `game\config` ya tiene el resultado. Para rehacerla desde el ELF:
```bat
bloody-roar4-recomp\tools\ghidra_br4.cmd        :: ~3 min -> game\config\config.toml + functions.csv
PS2Recomp\out\build\ps2xAnalyzer\Release\ps2_analyzer.exe game\iso\SLES_518.77 game\config\config.analyzer.toml
powershell -File bloody-roar4-recomp\tools\fix_functions_csv.ps1 -Elf game\iso\SLES_518.77 -Csv game\config\functions.csv
powershell -File bloody-roar4-recomp\tools\find_gap_entries.ps1 -Elf game\iso\SLES_518.77 -Csv game\config\functions.csv -Out game\config\gap_entries.txt
powershell -File bloody-roar4-recomp\tools\merge_config.ps1
```
(`ps2_analyzer` necesita configurar con `-DPS2X_BUILD_ANALYZER=ON`.) `merge_config.ps1` junta lo exportado por
Ghidra (`config.ghidra_original.toml`), los stubs SCE que reconoce `ps2_analyzer` y los puntos de entrada de los
huecos: 301 stubs y 680 puntos de entrada; reproduce el `config.toml` del repositorio byte a byte.
`tools\decomp.cmd` descompila o busca referencias en el proyecto de Ghidra.

## Regenerar los parches

Desde los árboles de código, contra los commits fijados (con los archivos nuevos sin seguimiento, sin el código
generado):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\make_patches.ps1 -Pcsx2 C:\BloodyRoar4Recomp\pcsx2 -Check
```
`-Check` clona los dos árboles en una carpeta temporal, hace checkout de `2c5fbb9` / `d073d75` y comprueba que
cada parche aplica limpio (`git apply --check`); `-CheckOnly` solo hace eso. Lo generado nunca entra en
`ps2recomp.patch`: `ps2xRuntime/src/runner/*`, `ps2xRuntime/include/ps2_recompiled_functions.h` y
`ps2_recompiled_stubs.h`.

## Pruebas

- `tools\run_test.ps1 -Seconds 90 -Shots 20,40,60 [-Ini br4_dlss.ini] [-Env @{PS2X_PAD_SCRIPT="30:START"}]`:
  arranca el juego en ventana, pide capturas al render en esos segundos (`logs\<tag>\shot_*.png`) y lo cierra.
  `PS2X_PAD_SCRIPT="<s>:<BOTON>,..."` pulsa botones solo (p. ej. para llegar a una pelea) y `PS2X_FPS_LOG=1`
  registra los fps.
- `tools\capture_dlss5.ps1`: lo mismo con el render de DLSS 5, capturando la ventana tal como se ve (con el
  pase neural, que las capturas del propio render no incluyen); `-Compare` pulsa F6 y captura con y sin él.
- Logs: `logs\play.log`, `logs\play_err.log` (juego), `gshost\logs\emulog.txt` (render).

## Variables de entorno

| Variable | Efecto |
|---|---|
| `BR4_ROOT` | carpeta del proyecto (por defecto `C:\BloodyRoar4Recomp`) |
| `PS2X_GS_LIVE=1` | dibuja con el render de PCSX2 en vivo (la pone el launcher) |
| `PS2X_PAD_ANALOG=1` | el mando arranca en modo analógico (la pone el launcher: el ANALOG del mod) |
| `PS2X_LIVE_SERIAL`, `PS2X_LIVE_TITLE` | `SLES-51877` (arreglos por juego de PCSX2) y el título de la ventana |
| `PS2X_CD_IMAGE` | la imagen del disco (por defecto `game\BloodyRoar4.iso`) |
| `PS2X_GSHOST`, `PS2X_GSHOST_ARGS`, `PS2X_HOST_WINDOW` | exe del render, sus argumentos (`-renderer vulkan -ini br4.ini -fullscreen`) y tamaño de ventana |
| `PS2X_BR4_WIDESCREEN=0` | imagen 4:3 original (sin parche panorámico) |
| `PS2X_BR4_STICK=0`, `PS2X_BR4_STICK_DEADZONE=n` | stick izquierdo -> cruceta apagado / zona muerta 0..127 (48) |
| `PS2X_PATH3_ONE_PACKET=0`, `PS2X_PATH3_VIA_DIRECT=0` | vuelve al PATH3 anterior (diagnóstico) |
| `PS2X_IOP_RPC_LOG=n`, `PS2X_PATH3_TRACE=<s>`, `PS2X_GS_DUMP` | diagnóstico: llamadas RPC del IOP, traza de PATH3, volcado del GS |

## Contribuir

Issues y pull requests son bienvenidos. Lee antes [PORTING_NOTES.md](PORTING_NOTES.md).

**Nunca** subas archivos del juego (ISO, ELF, archivos extraídos, código generado en `game\output` o
`ps2xRuntime\src\runner`, partidas) ni binarios (render, DLSS de NVIDIA, ReShade, add-ons). Para cambios en
PS2Recomp o PCSX2, regenera los parches con `tools\make_patches.ps1 -Check`.
