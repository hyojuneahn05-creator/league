part of '../home_page.dart';

class CardBase extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSoccer;
  final VoidCallback onStart;

  const CardBase({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSoccer,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black87, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 8),
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                isSoccer ? Icons.sports_soccer : Icons.sports_baseball,
                size: 180,
                color: Colors.grey,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: onStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E6FF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Start',
                      style: TextStyle(
                        color: Color(0xFF9555FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
