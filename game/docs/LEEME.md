# Dungeon Living

Doble clic en `game/Jugar.cmd`. Usa el Godot incluido en `godot/`; no necesita instalar otro motor.

Resolución interna 480 × 300, ventana 960 × 600 y filtrado nearest. La interfaz permanente ocupa únicamente una barra inferior. `I` abre el inventario y `F1` la guía.

- WASD / flechas: caminar en tiempo real.
- E: recoger, abrir, cerrar, empujar o usar objetos próximos.
- Espacio: golpear; con el pico equipado en la mano, excavar.
- X: buscar puertas secretas y trampas.
- I: mochila; flechas seleccionan objeto, Tab cambia ranura y Enter equipa.
- U / G, en la mochila: consumir / soltar.
- Q: activar o desactivar la autonomía tras cinco segundos.
- F5: guardar. Esc: pausa. También se guarda al cerrar.

Tres familias visuales se distribuyen por sectores: piedra y objetos del paquete `PNG`, arenisca del atlas `Dungen Tiles 2` y catacumbas del paquete `another tileset`. GreyMan conserva los grupos de cuatro filas de reposo, movimiento y combate.

Dentro de cada grupo, las filas de GreyMan son derecha, izquierda, abajo y arriba. La generación usa sectores de 48 × 48, salas con retranqueos, corredores de dos tiles y accesos con jambas verificadas. Los cambios de estilo ocurren en umbrales de pasillos, fuera de las salas.

La revisión de generación 2 conserva el inventario y equipo de partidas antiguas, sitúa al personaje en la sala inicial nueva y respalda el guardado completo anterior junto al archivo de partida con el sufijo `.before-layout-2`. La niebla y las excavaciones del mapa anterior permanecen en ese respaldo, porque sus coordenadas no corresponden al nuevo trazado.

El estado del mundo, las interacciones, el inventario, el personaje, el guardado, la autonomía y la presentación viven en clases separadas. `DungeonTerrainPainter` monta los muros por vecindad con coronas y caras verticales separadas, sin cambiar la cuadrícula de colisión. Cada objeto declara su daño y capacidades en el catálogo: pan, ración y soga hacen cero daño.

Pruebas desde la carpeta del repositorio:

```powershell
.\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path game --script tests/test_dungeon.gd
.\godot\Godot_v4.7.2-stable_win64_console.exe --path game --script tests/visual_smoke.gd
```
