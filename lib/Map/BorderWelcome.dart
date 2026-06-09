import 'dart:math';
import 'package:flutter/material.dart';

class BorderWelcome extends StatefulWidget {
  final String municipalityName;
  final VoidCallback onProceed;

  const BorderWelcome({
    super.key,
    required this.municipalityName,
    required this.onProceed,
  });

  @override
  State<BorderWelcome> createState() => _BorderWelcomeState();
}

class _BorderWelcomeState extends State<BorderWelcome> with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Background gradient rotation (15s for smooth, slow movement)
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Pulse for the location icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Content cinematic entrance animation
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _contentController, curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)),
    );

    // Start content animation after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031024),
      body: Stack(
        children: [
          // --- OPTIMIZATION: RepaintBoundary around the rotating background ---
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: SweepGradient(
                      center: FractionalOffset.center,
                      startAngle: 0.0,
                      endAngle: pi * 2,
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      colors: const [
                        Color(0xFF0A2E5C),
                        Color(0xFF00695C),
                        Color(0xFF10B981),
                        Color(0xFF1D4E89),
                        Color(0xFF0A2E5C),
                      ],
                      transform: GradientRotation(_bgController.value * 2 * pi),
                    ),
                  ),
                );
              },
            ),
          ),

          // Dark tint overlay (no BackdropFilter; it renders grey/blank on first frames in release)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF020B18).withValues(alpha: 0.6),
            ),
          ),

          // --- OPTIMIZATION: RepaintBoundary isolates the particle drawing engine ---
          const Positioned.fill(
            child: RepaintBoundary(
              child: FloatingParticles(),
            ),
          ),

          // --- FOREGROUND CONTENT ---
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // --- ISOLATED PULSING ICON ---
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3 + (_pulseController.value * 0.4)),
                                    blurRadius: 30 + (_pulseController.value * 20),
                                    spreadRadius: 5 + (_pulseController.value * 15),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                size: 70,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 40),

                        const Text(
                          "MABUHAY! YOU HAVE CROSSED INTO",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 4.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Static ShaderMask (High performance)
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFBBF24),
                              Color(0xFFFDE047),
                              Color(0xFF10B981),
                              Color(0xFF34D399),
                            ],
                          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                          child: Text(
                            widget.municipalityName.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              height: 1.05,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        Text(
                          "Discover new hidden gems, breathtaking ports, and stay protected with local emergency alerts in ${widget.municipalityName}.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Frosted button (no BackdropFilter; renders grey/blank on first frames in release)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onProceed,
                                  highlightColor: Colors.white.withValues(alpha: 0.2),
                                  splashColor: Colors.white.withValues(alpha: 0.3),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          "Begin Exploring",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PARTICLE SYSTEM ENGINE ---

class FloatingParticles extends StatefulWidget {
  const FloatingParticles({super.key});

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> particles = [];
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    // Cache particles to avoid creating objects during frames
    for (int i = 0; i < 35; i++) {
      particles.add(Particle(random));
    }

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..addListener(() {
        for (var particle in particles) {
          particle.update();
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder isolates the 60fps tick strictly to the CustomPainter
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(particles),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  double speed;
  double size;
  double maxOpacity;
  Random random;

  Particle(this.random)
      : x = random.nextDouble(),
        y = random.nextDouble(),
        speed = 0.0008 + random.nextDouble() * 0.0015, // Slightly slower, more elegant
        size = 1.0 + random.nextDouble() * 2.5,
        maxOpacity = 0.1 + random.nextDouble() * 0.5;

  void update() {
    y -= speed;
    x += (random.nextDouble() - 0.5) * 0.001;

    if (y < 0) {
      y = 1.0;
      x = random.nextDouble();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Calculate opacity: fade out near the top (y -> 0)
      double currentOpacity = particle.maxOpacity * particle.y;

      _particlePaint.color = Colors.white.withValues(alpha: currentOpacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        _particlePaint,
      );
    }
  }

  // Optimize: Return true only to force repaint on controller tick
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
