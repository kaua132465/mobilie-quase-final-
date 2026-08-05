import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/data_helpers.dart';
import '../core/theme.dart';

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(backgroundColor: AetherColors.success, content: Text(message)),
    );
}

void showFailure(BuildContext context, Object error) {
  final message = error is ApiFailure ? error.message : error.toString();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(backgroundColor: AetherColors.danger, content: Text(message)),
    );
}

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

class PageBody extends StatelessWidget {
  const PageBody({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 28),
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      child: Padding(padding: padding, child: child),
    );
    if (!scrollable) return content;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: content,
    );
  }
}

class AetherLogo extends StatelessWidget {
  const AetherLogo({this.height = 58, this.wordmark = false, super.key});

  final double height;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      wordmark
          ? 'assets/images/aether_wordmark.png'
          : 'assets/images/aether_logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.sports_soccer, size: height, color: AetherColors.navy),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AetherColors.navyDark,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: color,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: card,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    super.key,
  });

  final String label;
  final Object value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AetherColors.beigeStrong,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AetherColors.navy),
          ),
          const Spacer(),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AetherColors.navyDark,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final Object? status;

  @override
  Widget build(BuildContext context) {
    final normalized = status?.toString().toUpperCase() ?? '';
    final color = switch (normalized) {
      'EM_ANDAMENTO' || 'ATIVA' || 'APROVADA' => AetherColors.success,
      'AGENDADA' || 'INSCRICOES_ABERTAS' || 'PENDENTE' => AetherColors.warning,
      'ENCERRADA' || 'FINALIZADA' => AetherColors.navy,
      'CANCELADA' || 'REJEITADA' => AetherColors.danger,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message = 'Nenhum registro encontrado.',
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 62,
              color: AetherColors.navy.withValues(alpha: .35),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiFailure
        ? (error as ApiFailure).message
        : error.toString();
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Não foi possível carregar',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Tentar novamente'),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.message = 'Carregando...', super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class SearchBarField extends StatelessWidget {
  const SearchBarField({
    required this.controller,
    required this.onSubmitted,
    this.hint = 'Buscar',
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onSubmitted('');
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: AetherColors.navy),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class MatchCard extends StatelessWidget {
  const MatchCard({required this.data, this.onTap, super.key});

  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final home = textOf(data, [
      'time_casa',
      'timeCasa',
      'mandante',
    ], fallback: 'Time A');
    final away = textOf(data, [
      'time_visitante',
      'timeVisitante',
      'visitante',
    ], fallback: 'Time B');
    final homeScore = intOf(data, ['placar_casa', 'placarCasa']);
    final awayScore = intOf(data, ['placar_visitante', 'placarVisitante']);
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  textOf(data, ['competicao'], fallback: 'Competição'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AetherColors.navy,
                  ),
                ),
              ),
              StatusBadge(data['status']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  home,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AetherColors.beigeStrong,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$homeScore × $awayScore',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AetherColors.navyDark,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  away,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule, size: 17, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatDate(
                    data['data_hora'] ?? data['dataHora'],
                    withTime: true,
                  ),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Colors.black45,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  textOf(data, ['local'], fallback: 'Local a definir'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

String? requiredField(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo obrigatório';
  return null;
}

String? emailField(String? value) {
  final required = requiredField(value);
  if (required != null) return required;
  final email = value!.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Informe um e-mail válido';
  }
  return null;
}
