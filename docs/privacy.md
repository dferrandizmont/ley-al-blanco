# Privacidad y cumplimiento

No es asesoramiento jurídico. Resume qué hace la app con los datos; revisar con un profesional antes del lanzamiento.

## Flujo de datos (decisión del dueño, 26-oct-2026)
- **Nada sale del móvil desde la app.** Progreso, fallos, repaso espaciado, simulacros y ajustes viven en Drift; la racha de la pregunta del día también es local y solo sale en el archivo de progreso que el usuario exporta.
- App 100 % gratuita y de código abierto: código MIT y contenido propio CC BY-SA 4.0; el repositorio está publicado en https://github.com/dferrandizmont/ley-al-blanco. Banco y teoría incluidos, disponibles sin conexión y sin cuentas.
- Sin compras, anuncios, analítica ni identificadores de instalación. Único componente de terceros: la biblioteca de valoraciones de Google Play (`in_app_review`, con Play Review y play-services-base) en Android; en iOS, StoreKit del sistema. No se transmiten informes de errores; el manejo de fallos usa únicamente el registro local del sistema.
- Las claves antiguas de compras e informes de errores se conservan sin uso por compatibilidad; no se consultan ni se exportan.

## Exportar e importar progreso
El usuario elige el archivo con el diálogo del sistema. La app no solicita permisos generales de almacenamiento ni envía el archivo a ningún servidor. El JSON contiene respuestas, repaso, simulacros, apariencia y la racha de la pregunta del día; no está cifrado. El destino y lo que el usuario haga después con ese archivo quedan bajo su control.

El archivo lleva además, cuando se conocen, la hora (en UTC) de la última respuesta acreditada de la pregunta del día, la diferencia horaria del móvil en ese momento y el día de vencimiento de cada repaso. Son datos del propio dispositivo, no identifican a nadie y solo salen en el archivo que el usuario exporta a propósito.

La importación valida tamaño (10 MB), profundidad (8 niveles), formato, versión, edición, tipos, rangos y fechas antes de sustituir el progreso en una sola transacción. Recalcula aciertos y notas con el banco. Los campos antiguos de compra, ofertas y simulacro gratuito se ignoran sin error. Todos los temas y simulacros importados se pueden abrir.

Importar reemplaza todo el progreso del móvil, la racha de la pregunta del día incluida: si el archivo la trae, se aplica; si no la trae (un archivo exportado antes de que la racha viajara), se borra la del móvil.

El selector puede crear archivos temporales. Android limpia la caché del plugin; iOS elimina solo la copia concreta que acaba de leer dentro del directorio temporal. Los mensajes técnicos de validación quedan en el registro local.

## Copias y acciones externas
Las copias del sistema operativo, si el usuario las habilita, las gestiona su cuenta de Google o Apple fuera de la app. La app no implementa sincronización ni copias remotas.

«Escribir a soporte» y «¿Ves un error? Avísanos» abren el correo del usuario, que puede revisar y enviar el mensaje. Soporte: **leyalblanco@mainshai.com** (hasta el 30-oct-2026, dev@mainshai.com). El soporte incluye versión de app y sistema; el aviso de una pregunta añade el contenido de esa pregunta, nunca progreso ni identificadores.

**Valoración en iPhone (1.0.1, 12-nov-2026; sustituido por el párrafo siguiente):** tras el primer simulacro apto de cada versión, la app pide a iOS el diálogo de valoración del sistema (StoreKit, `AppStore.requestReview`). Es el diálogo de Apple: la app no envía ningún dato, no sabe si el usuario valora ni qué pone, y Apple decide si se muestra (como mucho tres veces al año; en TestFlight nunca). En el móvil solo se guarda la versión en la que se pidió, para no repetirlo. En Android no hace nada.

**Valoración en Android e iOS con `in_app_review` (desde la versión siguiente a la 1.0.1, 13-nov-2026, decisión del dueño):** sustituye al canal nativo de iOS. Tras un simulacro apto, la app pide a la tienda su ventana de valoración (Play In-App Review en Android, StoreKit en iOS) solo si han pasado 7 días desde la primera apertura, se ha abierto 5 días distintos, hay al menos un simulacro terminado, no se ha importado progreso en los últimos 7 días, y como mucho 3 veces, una por versión y con 90 días entre ellas. Ajustes > Ayuda > «Valorar Ley al Blanco» abre la ficha de la tienda. La app solo pasa a la tienda el identificador de la app (nombre de paquete), nunca uno del usuario o del dispositivo; las reseñas son públicas y el dueño las ve en Play Console y App Store Connect. Se guarda en `SharedPreferences` (`review.state`): primera apertura, días de apertura, última importación, fechas y versiones de las peticiones; no va en la exportación de progreso, pero sí en la copia del sistema si está activada. Data safety de Play: «no se recogen ni comparten datos» (decisión del dueño, 13-nov-2026; razonamiento en `docs/play-console.md` §10). El dueño acepta que el APK de GitHub lleve estas bibliotecas propietarias de Google; fuera de Play no se muestra ninguna ventana.

La fuente y la política de privacidad se abren en el navegador externo solo al pulsar sus enlaces. `SUPPORT_EMAIL` y `PRIVACY_URL` se mantienen como opciones del build; vacíos ocultan esas filas. «Licencias de código abierto» está siempre disponible y se abre sin conexión.

## Declaraciones en tiendas
- App Store, App Privacy: **no se recogen datos**, sin seguimiento ni compras dentro de la app.
- Google Play, Seguridad de los datos: **no se recogen ni comparten datos** desde la app (también con la valoración en la tienda, ver arriba); sin anuncios ni compras. No hay cuentas que borrar; el progreso se elimina desde el sistema o desinstalando.
- Revisar los formularios definitivos y publicar una URL de política coherente con estos hechos.

## Atribución del cuestionario
- Fuente: programa de la prueba teórica de licencias D, E y AEM, publicado por la Dirección General de la Guardia Civil: https://web.guardiacivil.es/es/tramites/autorizaciones-de-armas-y-explosivos/controldearmas/pruebas_licenciasarmas/Programa_prueba_teorica_D__E_y_AEM/index.html (consultado el 18-oct-2026).
- Reutilización conforme a la Ley 37/2007 (reutilización de la información del sector público): **se cita la fuente y la fecha y no se altera el sentido** (enunciados, opciones y respuesta oficial tal cual).
- Texto fijo en Ajustes y en la ficha: app independiente y no oficial; sin logos ni escudo.
- Las explicaciones son de redacción propia.

## Pendiente antes del lanzamiento
- [x] Publicar la política de privacidad (URL) y enlazarla desde Ajustes y las dos tiendas.
- [x] Pasar `--dart-define=PRIVACY_URL=https://...` (política publicada) en el build de release: sin él, Ajustes no muestra «Política de privacidad».
- [x] Configurar el buzón leyalblanco@mainshai.com y pasar `--dart-define=SUPPORT_EMAIL=leyalblanco@mainshai.com` en el build de release: sin él, Ajustes no muestra «Escribir a soporte».
- [ ] Comprobar en un build de release de cada tienda que «Escribir a soporte», «Política de privacidad» y «Ver la fuente original» abren la app externa correcta.
- [ ] Escribir a la Intervención Central de Armas pidiendo confirmación de reutilización; guardar la respuesta.
- [ ] Seguridad de los datos (Play): hecho. App Privacy (Apple): pendiente de crear la app.
- [ ] Revisar este documento cada vez que cambie el flujo de datos.
