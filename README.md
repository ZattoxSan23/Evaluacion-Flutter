# Evaluaciones deportivas — Flutter

Aplicación Flutter/Dart conectada a Supabase, con pantallas para administrador, entrenador y cliente. Contiene gestión de rutinas, planes de alimentación, medidas y un temporizador de entrenamiento con videos.

## Ejecutar y verificar

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Usa una versión de Flutter compatible con las dependencias de `pubspec.yaml` y Dart 3.3 o superior. Las carpetas Android/iOS/web/desktop no garantizan que todos los plugins funcionen en cada plataforma: verifica especialmente YouTube, tareas en segundo plano y wakelock en el destino elegido.

## Datos y acceso

`lib/core/supabase_client.dart` inicializa la conexión pública existente. Las cuentas requieren perfil con rol `admin`, `trainer` o `client`. El proyecto no incluye un esquema completo y reproducible de Supabase ni cuentas demo provisionadas.

Los permisos de las pantallas no sustituyen RLS. La recuperación de contraseña usa un deep link que requiere configuración adicional en la aplicación y Supabase.

## Organización real

- `lib/screens/`: implementación de pantallas y gran parte de las consultas.
- `lib/core/supabase_client.dart`: cliente compartido.
- `lib/models/`: modelos y serialización.
- `lib/services/`, `lib/providers/` y algunos widgets contienen archivos vacíos: son estructura pendiente, no una capa de servicios implementada.

El temporizador cancela su Timer al salir, evita actualizar estado tras desmontarse y finaliza en el tick que llega a cero. Sigue necesitando una estrategia basada en tiempo real para suspensión de la app o bloqueo del dispositivo.

## Pruebas

`test/widget_test.dart` verifica el botón de formulario real: envío, estado deshabilitado y bloqueo durante carga. No inicializa Supabase ni depende de cuentas externas. Se retiró la prueba de contador de la plantilla porque la app no tiene ese contador.

## Pendientes

Extraer consultas de pantallas a servicios de verdad; completar o eliminar archivos vacíos; versionar esquema/RLS y seed de demostración; probar sesiones vencidas, navegación durante cargas y recuperación de contraseña; persistir progreso del entrenamiento y definir soporte por plataforma.

## Capturas y descripción original

# 🏋️‍♂️ App Multiplataforma para Evaluaciones Deportivas

Aplicación **multiplataforma desarrollada en Flutter** orientada a la **gestión y evaluación del rendimiento deportivo**, con distintos roles de usuario y flujos personalizados según permisos.

El sistema está diseñado para **instituciones deportivas, entrenadores y deportistas**, permitiendo registrar, evaluar y visualizar resultados de manera clara e intuitiva.

---

## 🚀 Tecnologías Utilizadas

- **Flutter** – Desarrollo multiplataforma  
- **Dart**  
- **Material Design**  
- **Arquitectura por roles**  
- **Gestión de formularios y validaciones**  
- **UI/UX enfocada en usabilidad móvil**

---

## 🔐 Roles del Sistema

La aplicación maneja **tres tipos de usuarios**, cada uno con funcionalidades específicas:

### 👑 Administrador
- Gestión general del sistema  
- Administración de usuarios  
- Visualización y control de evaluaciones  
- Acceso completo a los módulos  

### 🏃‍♂️ Entrenador
- Registro de evaluaciones deportivas  
- Gestión de deportistas  
- Seguimiento de resultados  
- Visualización de métricas de rendimiento  

### 👤 Cliente / Deportista
- Visualización de evaluaciones  
- Consulta de resultados personales  
- Seguimiento de progreso  

---

## 📱 Pantallas del Sistema

### 🔑 Pantalla 1 – Login
Autenticación de usuarios según rol, con validación de credenciales.

<p align="center">
  <img src="https://github.com/user-attachments/assets/dc6b16f0-f295-44a3-8990-d33e84f74846" width="300"/>
</p>

---

## 👑 Administrador
Interfaz dedicada a la administración y control general del sistema.

<p align="center">
  <img src="https://github.com/user-attachments/assets/76161edf-1131-4522-a059-1f135de73d3d" width="240"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/2204c86b-b93a-46f6-826b-bf39a0145a78" width="240"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/74eeba9a-542c-4270-96e9-0709ece5169c" width="240"/>
</p>

---

## 🏃‍♂️ Entrenador
Módulos enfocados en el registro y evaluación del rendimiento deportivo.

<p align="center">
  <img src="https://github.com/user-attachments/assets/7f8a46d8-499c-45a1-a41d-ec8912daf5a6" width="220"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/d64790ec-d18d-4d7f-b22d-add6902e23b5" width="220"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/5eedd2d3-fb3c-47a3-ba8f-602cc5b064f8" width="220"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/98d3ebc7-2c1f-4993-9007-d7d60fb837b7" width="220"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/4bb23905-6e0c-4b0b-b1db-3c08e985d7c5" width="220"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/fa102b30-0eab-4975-96a3-19ba7ac440e0" width="220"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/44bbd21c-8678-401f-a06e-113221c25d5a" width="220"/>
</p>

---

## 👤 Cliente / Deportista
Pantallas enfocadas en la visualización de resultados y seguimiento personal.

<p align="center">
  <img src="https://github.com/user-attachments/assets/d8098e3b-68d1-406c-873d-29835fec300c" width="240"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/faf32f15-62f5-4cb2-899f-6bb8ec57d520" width="240"/>
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/0ec4cc12-e0c7-482c-a5fd-6f4537633171" width="240"/>
</p>




DEMO


https://nimble-conkies-f9047e.netlify.app 

CUENTA

ENTRENADOR : treno@gmail.com CONTRASEÑA : 123456 
CLIENTE : gladys@gmail.com  CONTRASEÑA : 19325035
ADMINISTRADOR: administrador@gym.com CONTRASEÑA: 123456


---

## ⚙️ Cómo Ejecutar el Proyecto

```bash
# Clonar el repositorio
git clone https://github.com/ZattoxSan23/Evaluacion-Flutter.git

# Entrar al proyecto
cd Evaluacion-Flutter

# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run
