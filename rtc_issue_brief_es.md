## Resumen del Problema
Se ha detectado una falla crítica de persistencia y estabilidad en el **Real-Time Clock (RTC)** del chipset SL8541E (PMIC SC2721G). Esto provoca variaciones de tiempo impredecibles:
- **Reseteos Totales**: Retorno a la fecha base al apagar el equipo.
- **Desplazamientos y Retrasos (Drift/Lag)**: El reloj puede "quedarse atrás" o pausarse temporalmente durante el funcionamiento, resultando en desfases de **varios minutos (ej. 6 minutos de retraso)** respecto a la hora real.

Estos fallos invalidan mecanismos de seguridad basados en ventanas de tiempo, como la generación de firmas **HMAC**, causando el rechazo de timestamps por el servidor.

## Causas Raíz (Nivel Hardware)

1.  **Ausencia de VBACKUP**: Gran parte de estos diseños omiten capacitores de respaldo. El RTC depende totalmente de la batería principal.
2.  **Inestabilidad del Cristal (Stalling)**: El cristal oscilador de 32.768 kHz es extremadamente sensible al ruido eléctrico del módem 4G y la CPU. Durante picos de consumo, el oscilador puede "hibernar" o perder ciclos, lo que se traduce en un **retraso acumulado** (el reloj camina más lento que el tiempo real).
3.  **Brownouts y Corrupción de Registros**: Las caídas de tensión (brownouts) pueden no apagar el RTC pero sí "ensuciar" sus registros, causando que el contador de tiempo salte a valores aleatorios o fechas por defecto del firmware.

## Impacto en Autenticación HMAC
El uso de HMAC con ventanas de tiempo (Time-based Tokens) asume que el `timestamp` del dispositivo es síncrono con el servidor. 
- **Falsos Rechazos**: Si el RTC retrocede a momentos pasados, el servidor rechazará la firma por estar fuera de la ventana de validez (skew excesivo).
- **Inconsistencia en Ejecución**: Si el RTC "se pausa" o "tartamudea" durante el funcionamiento del dispositivo por ruidos en el bus de reloj, el tiempo del sistema puede derivar varios minutos o segundos, causando fallos intermitentes de autenticación incluso sin un reinicio completo.

## Recomendaciones de Eficiencia (Batería y Datos)

El objetivo es estabilizar el tiempo **sin realizar peticiones de red constantes**.

### 1. El Protocolo NITZ (Tiempo de Red Celular)
- **Ventaja**: Es una sincronización pasiva que ocurre al conectar con la torre celular. No consume datos y es el método más eficiente.
- **Limitación (¿Es fiable?)**: No todas las torres de telefonía emiten NITZ con la misma frecuencia. Si el dispositivo está en una zona de señal muy débil o estática, la actualización puede tardar varios minutos desde el arranque. 

### 2. Estrategia de "Sincronización Mínima"
Para asegurar que el HMAC no sea rechazado sin gastar datos extras, se recomienda esta jerarquía de confianza:
1.  **Verificación Inicial**: Al arrancar la app, usar `elapsedRealtime()` para medir intervalos, pero esperar a un flag de "Tiempo Sincronizado" (NITZ).
2.  **Trigger por Demanda**: Solo si han pasado X minutos sin NITZ **y** se necesita generar un HMAC crítico, realizar una **única** petición NTP minimalista (un solo paquete UDP de 48 bytes) para obtener el "offset" inicial. 
3.  **Caché de Offset**: Una vez obtenida la hora real (vía NITZ o la única petición NTP), guardar la diferencia respecto al tiempo monotónico en memoria. A partir de ahí, la app calcula la hora sumando ese offset al tiempo monotónico, permitiendo que el RTC del hardware falle sin afectar la lógica.

### 3. Alternativas de Seguridad "One-Trip" (1 Solo Viaje)
Para maximizar el ahorro de batería y datos sin depender del RTC, estas son las mejores opciones de arquitectura:

- **HOTP / HMAC Secuencial (Recomendado)**: Basado en un contador de eventos (`Sequence ID`) en lugar de tiempo. Cliente y servidor incrementan un contador por cada mensaje exitoso. 
    - **Pros**: Inmune al tiempo, máximo ahorro (1 solo viaje de red).
    - **Contras**: Requiere lógica en el servidor para "resincronizar" si el cliente pierde su estado (ej. borrado de caché de app).
- **mTLS (Mutual TLS)**: Autenticación por certificados en ambos lados.
    - **Pros**: Altísima seguridad a nivel de transporte.
    - **Trampa Crítica**: **mTLS TAMBIÉN depende del RTC**. Los certificados tienen fechas de validez (`Not Before` / `Not After`). Si el dispositivo vuelve a 1970, el mTLS fallará porque pensará que el certificado del servidor aún no es válido. Además, el intercambio de certificados consume más datos que un simple HMAC.
- **Hash de Identificador Único + Sal**: Un hash simple `SHA256(Data + DeviceID + Secret)`.
    - **Pros**: El más rápido y ligero.
    - **Contras**: Vulnerable a **Ataques de Replay** (un atacante puede capturar y reenviar el mismo paquete exacto). Solo es seguro si el canal es TLS y el servidor detecta duplicados por otros medios.

## Solución Superior: Session-based HMAC con Sincronización Monotónica

Esta es la arquitectura recomendada para maximizar la **seguridad**, el **ahorro de batería** y el **mínimo consumo de datos** en el SL8541E:

1.  **Handshake Único (Estratégico)**: Al arrancar la app o una vez al día, realizar una única sincronización externa para obtener la `HoraReal` y un `SessionKey`.
2.  **Cálculo de Offset**: Guardar la diferencia `Offset = HoraReal - SystemClock.elapsedRealtime()`.
3.  **Monotonic Loop (1-Trip)**: Para todos los mensajes posteriores, la app calcula la hora virtual `VirtualTime = elapsedRealtime() + Offset` y firma con HMAC usando la `SessionKey`.

**Beneficios**:
- **Inmune a Reseteos y Lags del RTC**: Aunque el reloj de hardware se atrase 6 minutos o vuelva a 1970, el contador monotónico del CPU (`elapsedRealtime`) sigue siendo exacto.
- **Eficiencia Extrema**: Todos los mensajes conservan la estructura de un solo viaje (1-trip), ahorrando el 50% de radio y datos frente a sistemas de Nonce tradicional.

---

## Uso de Tiempo Monotónico
- Obligatorio para toda la lógica de ejecución interna. `SystemClock.elapsedRealtime()` no depende del RTC ni de la red, consume el mínimo de energía y garantiza que los intervalos siempre sean positivos y lineales.
