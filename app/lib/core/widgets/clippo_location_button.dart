import 'package:flutter/material.dart';

import 'package:clippo/core/location/current_place.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';

/// "Usar localização atual", embaixo do campo Local (Confirme a sessão e Editar sessão).
///
/// Só pede o GPS quando tocado. Achou: [onPlace] recebe o nome do lugar, e a tela põe no campo
/// (continua editável). Não deu: [onError] recebe a frase para ir embaixo do campo.
class ClippoLocationButton extends StatefulWidget {
  const ClippoLocationButton({super.key, required this.onPlace, required this.onError, this.findPlace});

  final ValueChanged<String> onPlace;
  final ValueChanged<String> onError;

  /// Substitui o GPS (testes). Nulo = [CurrentPlace.label].
  final Future<String> Function()? findPlace;

  @override
  State<ClippoLocationButton> createState() => _ClippoLocationButtonState();
}

class _ClippoLocationButtonState extends State<ClippoLocationButton> {
  bool _busy = false;

  Future<void> _find() async {
    setState(() => _busy = true);
    try {
      final place = await (widget.findPlace ?? const CurrentPlace().label)();
      if (mounted) widget.onPlace(place);
    } on LocationFailure catch (e) {
      if (mounted) widget.onError(e.message);
    } catch (_) {
      if (mounted) widget.onError('Não deu para usar a localização. Digite o local.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: _busy,
      child: ClippoTextButton(
        label: _busy ? 'Buscando onde você está…' : 'Usar localização atual',
        onPressed: _busy ? null : _find,
      ),
    );
  }
}
