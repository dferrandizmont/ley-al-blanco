# Privacidad y cumplimiento

No es asesoramiento jurídico. Resume qué hace la app con los datos; revisar con un profesional antes del lanzamiento.

## Flujo de datos (decisión del dueño, 26-oct-2026)
- **Nada sale del móvil desde la app.** Progreso, fallos, repaso espaciado, simulacros y ajustes viven en Drift; la racha de la pregunta del día también es local y no se exporta.
- App 100 % gratuita y de código abierto: código MIT y contenido propio CC BY-SA 4.0; la publicación del repositorio está pendiente. Banco y teoría incluidos, disponibles sin conexión y sin cuentas.
- Sin compras, anuncios, analítica, identificadores de instalación ni servicios de terceros. No se transmiten informes de errores; el manejo de fallos usa únicamente el registro local del sistema.
- Las claves antiguas de compras e informes de errores se conservan sin uso por compatibilidad; no se consultan ni se exportan.

## Exportar e importar progreso
El usuario elige el archivo con el diálogo del sistema. La app no solicita permisos generales de almacenamiento ni envía el archivo a ningún servidor. El JSON contiene respuestas, repaso, simulacros y apariencia; no está cifrado. El destino y lo que el usuario haga después con ese archivo quedan bajo su control.

La importación valida tamaño (10 MB), profundidad (8 niveles), formato, versión, edición, tipos, rangos y fechas antes de sustituir el progreso en una sola transacción. Recalcula aciertos y notas con el banco. Los campos antiguos de compra, ofertas y simulacro gratuito se ignoran sin error. Todos los temas y simulacros importados se pueden abrir.

El selector puede crear archivos temporales. Android limpia la caché del plugin; iOS elimina solo la copia concreta que acaba de leer dentro del directorio temporal. Los mensajes técnicos de validación quedan en el registro local.

## Copias y acciones externas
Las copias del sistema operativo, si el usuario las habilita, las gestiona su cuenta de Google o Apple fuera de la app. La app no implementa sincronización ni copias remotas.

«Escribir a soporte» y «¿Ves un error? Avísanos» abren el correo del usuario, que puede revisar y enviar el mensaje. Soporte: **dev@mainshai.com**. El soporte incluye versión de app y sistema; el aviso de una pregunta añade el contenido de esa pregunta, nunca progreso ni identificadores.

La fuente y la política de privacidad se abren en el navegador externo solo al pulsar sus enlaces. `SUPPORT_EMAIL` y `PRIVACY_URL` se mantienen como opciones del build; vacíos ocultan esas filas. «Licencias de código abierto» está siempre disponible y se abre sin conexión.

## Declaraciones en tiendas
- App Store, App Privacy: **no se recogen datos**, sin seguimiento ni compras dentro de la app.
- Google Play, Seguridad de los datos: **no se recogen ni comparten datos** desde la app; sin anuncios ni compras. No hay cuentas que borrar; el progreso se elimina desde el sistema o desinstalando.
- Revisar los formularios definitivos y publicar una URL de política coherente con estos hechos.

## Atribución del cuestionario
- Fuente: programa de la prueba teórica de licencias D, E y AEM, publicado por la Dirección General de la Guardia Civil: https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/controldearmas/pruebas_licenciasarmas/Programa_prueba_teorica_D__E_y_AEM/index.html (consultado el 18-oct-2026).
- Reutilización conforme a la Ley 37/2007 (reutilización de la información del sector público): **se cita la fuente y la fecha y no se altera el sentido** (enunciados, opciones y respuesta oficial tal cual).
- Texto fijo en Ajustes y en la ficha: app independiente y no oficial; sin logos ni escudo.
- Las explicaciones son de redacción propia.

## Pendiente antes del lanzamiento
- [ ] Publicar la política de privacidad (URL) y enlazarla desde Ajustes y las dos tiendas.
- [ ] Pasar `--dart-define=PRIVACY_URL=https://...` (política publicada) en el build de release: sin él, Ajustes no muestra «Política de privacidad».
- [ ] Configurar el buzón dev@mainshai.com y pasar `--dart-define=SUPPORT_EMAIL=dev@mainshai.com` en el build de release: sin él, Ajustes no muestra «Escribir a soporte».
- [ ] Comprobar en un build de release de cada tienda que «Escribir a soporte», «Política de privacidad» y «Ver la fuente original» abren la app externa correcta.
- [ ] Escribir a la Intervención Central de Armas pidiendo confirmación de reutilización; guardar la respuesta.
- [ ] Rellenar App Privacy (Apple) y Seguridad de los datos (Play).
- [ ] Revisar este documento cada vez que cambie el flujo de datos.
