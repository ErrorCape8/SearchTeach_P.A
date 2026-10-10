import 'package:flutter/material.dart';

const kBlue = Color(0xFF1E3FA8);
const kNavy = Color(0xFF14146B);
const kInk = Color(0xFF1C1F24);
const kField = Color(0xFFEDF0F5);

/// Marco común de las pantallas de autenticación.
/// - Ancho >= 900 (PC/tablet horizontal): panel de marca a la izquierda + formulario a la derecha.
/// - Ancho < 900 (celular): igual al mockup, cabecera azul + hoja blanca.
class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.onBack});
  final Widget child;
  final VoidCallback? onBack;

  static const breakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, c) {
        return c.maxWidth >= breakpoint ? _desktop() : _mobile(c);
      }),
    );
  }

  // ---------------- PC ----------------
  Widget _desktop() {
    return Row(children: [
      const Expanded(flex: 6, child: _BrandPanel()),
      Expanded(
        flex: 5,
        child: Stack(children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: child,
              ),
            ),
          ),
          if (onBack != null)
            Positioned(
              top: 24,
              left: 24,
              child: IconButton.filledTonal(
                  onPressed: onBack, icon: const Icon(Icons.arrow_back)),
            ),
        ]),
      ),
    ]);
  }

  // ---------------- Celular ----------------
  Widget _mobile(BoxConstraints c) {
    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          SizedBox(
            height: 150,
            child: Stack(alignment: Alignment.center, children: [
              const _LogoPill(),
              if (onBack != null)
                Positioned(
                  left: 16,
                  top: 12,
                  child: IconButton.filledTonal(
                      onPressed: onBack, icon: const Icon(Icons.arrow_back)),
                ),
            ]),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: child,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

const _gradient = RadialGradient(
  center: Alignment(-0.6, -0.9),
  radius: 1.6,
  colors: [Color(0xFF3D63D1), kNavy],
);

class _LogoPill extends StatelessWidget {
  const _LogoPill();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cast_for_education, color: kBlue),
          SizedBox(width: 10),
          Text('SEARCHTEACH',
              style: TextStyle(
                  color: kBlue, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      );
}

/// Panel izquierdo para pantallas grandes: así no queda vacío.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: _gradient),
      padding: const EdgeInsets.all(56),
      child: Stack(children: [
        // círculos decorativos
        Positioned(right: -80, top: -80, child: _circle(300, .06)),
        Positioned(left: -100, bottom: -120, child: _circle(380, .05)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LogoPill(),
            const Spacer(),
            const Text('Aprende y enseña,\ncuando y donde quieras.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    height: 1.15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Text(
              'Conecta con tutores y estudiantes de tu institución y agenda tutorías en minutos.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .8),
                  fontSize: 18,
                  height: 1.4),
            ),
            const SizedBox(height: 40),
            const _Feature(Icons.event_available, 'Agenda tutorías',
                'Solicita, acepta o propone un nuevo horario.'),
            const _Feature(
                Icons.videocam_outlined,
                'Clases virtuales o presenciales',
                'Elige la modalidad que mejor te funcione.'),
            const _Feature(Icons.insights, 'Sigue tu progreso',
                'Asistencia y estadísticas en un solo lugar.'),
            const Spacer(),
            Text('© ${DateTime.now().year} SearchTeach',
                style: TextStyle(color: Colors.white.withValues(alpha: .6))),
          ],
        ),
      ]),
    );
  }

  Widget _circle(double s, double o) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withValues(alpha: o)),
      );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              Text(subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: .75))),
            ]),
          ),
        ]),
      );
}

// ---------- Piezas reutilizables de formulario ----------

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, letterSpacing: 1.2, color: Color(0xFF5B6270))),
      );
}

InputDecoration fieldDecoration(String hint, {Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: kField,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5)),
    );

class DarkButton extends StatelessWidget {
  const DarkButton(this.label,
      {super.key, this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: kInk,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFE5484D),
              child: Icon(Icons.close, size: 16, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: Color(0xFF7A1212)))),
        ]),
      );
}
