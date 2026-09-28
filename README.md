# AppPrestamos

Aplicación Flutter multiplataforma con API Express/PostgreSQL. El desarrollo actual es local;
la prueba remota habitual se hace desde Safari en un iPhone a través de Tailscale.

## Antes de trabajar

La raíz real de Git es esta carpeta `AppPrestamos/`, no su carpeta padre `Proyecto_AppPrestamos/`.
La API activa está en `backend/`; Flutter está en `software1/`. `software1/backend/` es residual.
Preserva los cambios locales: la versión de referencia incluye trabajo sin commit.

**Para cualquier modelo/agente, empezar por [AGENTS.md](AGENTS.md).**

| Necesidad | Documento |
| --- | --- |
| Reglas obligatorias, permisos y carpeta correcta | [AGENTS.md](AGENTS.md) |
| Cómo planificar, aprobar, ejecutar y revisar una tarea | [Flujo entre modelos](docs/WORKFLOW.md) |
| Correr, detener, reiniciar o consultar estado | [Guía operativa canónica](docs/RUNTIME_RUNBOOK.md) |
| Retomar este proyecto/chat con otro modelo | [Contexto actual y traspaso](docs/CURRENT_STATE.md) |
| Elegir entre una solicitud sencilla y una tarea detallada | [Dos enfoques de trabajo](docs/WORKFLOW.md#two-routes--natural-language-intake) |
| Preparar una tarea formal en inglés | [Plantilla TXT](tasks/TEMPLATE.txt) |
| Documentar resultados, pruebas y bloqueos | [Plantilla de reporte](tasks/REPORT_TEMPLATE.md) |

## Nuestro flujo

Mantenemos dos enfoques según el impacto real del cambio:

- **Ligero (LIGHTWEIGHT):** puedes pedir directamente en OpenCode algo como «cambia a verde el botón de login».
  El agente localiza el código, propone un plan breve con alcance y comprobaciones y espera tu aprobación.
  Tu solicitud y el plan aprobado son el contrato: no necesitas un TXT preparado en este chat.
- **Detallado (FORMAL):** para cambios complejos, financieros, de permisos, datos o alcance compartido,
  este chat analiza y prepara una tarea específica en inglés. OpenCode presenta su plan y espera tu aprobación.

En ambos casos el ejecutor implementa, verifica y entrega evidencia y su reporte autorizado. Si un cambio sencillo
resulta tener mayor impacto, debe detener la ampliación y solicitar el enfoque formal, no improvisar más cambios.
Tú aceptas el resultado y puedes solicitar revisión técnica aquí; el worker no acepta su propio trabajo.
Solo hay una tarea de implementación y un ejecutor a la vez. Cambiar de tarea pendiente requiere una pausa/cambio explícito.
No se inicia la siguiente tarea automáticamente, ni se hacen commits o push sin orden explícita.

Los modelos trabajan uno después de otro sobre la misma copia. Los contratos, planes breves y reportes están en inglés;
la conversación contigo puede ser en español. Al cambiar de modelo, este debe leer el contexto actual
y verificar los archivos, no depender de recordar toda una conversación.

**Las reglas las mantenemos tú y el supervisor de este chat, no los ejecutores de OpenCode.**
Los ejecutores no pueden modificar AGENTS, README, guías, contexto compartido, contratos de tareas ni plantillas.
Su única documentación editable es el reporte específico autorizado de su tarea. Allí proponen correcciones;
nosotros las revisamos y, si corresponde, actualizamos los archivos compartidos. También deben comprobar que
los archivos protegidos no cambiaron. Esta es una regla de trabajo con verificación, no un bloqueo del sistema operativo.

## Operación y pruebas

Pedir `run`, `stop` o `restart` autoriza directamente el procedimiento ya definido en la guía operativa.
`status` solo inspecciona. No es necesario aprobar un segundo plan para esas operaciones conocidas.

URL canónica de iPhone Safari: **https://johans-macbook-pro.tailfbc2ea.ts.net:7358**.
La dirección documentada no implica que el servicio esté encendido en este momento.
Una página que carga no demuestra que login/CORS funcionen; la guía exige verificar ambos.

Reutilizamos la base local y las cuentas existentes. Las pruebas pueden crear registros identificables
dentro del plan aprobado; modificar datos anteriores o efectos sobre cuentas requiere permiso específico.
No se crean bases/logins por tarea ni se restaura o limpia la base automáticamente.
Los respaldos privados se hacen cuando son necesarios; nunca se suben a Git.

## Referencias históricas

[Contexto arquitectónico histórico](docs/PROJECT_CONTEXT.md) y
[guía local histórica](docs/LOCAL_DEVELOPMENT.md) conservan información útil, pero no reemplazan las reglas actuales.
Los scripts de `scripts/dev/` no son lanzadores aprobados: requieren una revisión separada.
Las antiguas TASK-001/TASK-001-A no están activas y no deben ejecutarse automáticamente.
El [AGENTS original](docs/archive/AGENTS-before-2026-09-19.md) se conserva para consulta, no como instrucciones vigentes.
