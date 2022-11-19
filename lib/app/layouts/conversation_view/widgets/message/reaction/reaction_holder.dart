import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class ReactionHolder extends StatefulWidget {
  ReactionHolder({
    Key? key,
    required this.reactions,
    required this.message,
  }) : super(key: key);
  final Iterable<Message> reactions;
  final Message message;

  @override
  State<ReactionHolder> createState() => _ReactionHolderState();
}

class _ReactionHolderState extends State<ReactionHolder> {
  Iterable<Message> get reactions => getUniqueReactionMessages(widget.reactions.toList());

  @override
  Widget build(BuildContext context) {
    // If the reactions are empty, return nothing
    if (reactions.isEmpty || (ss.settings.redactedMode.value && ss.settings.hideReactions.value)) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 35,
      width: 35,
      child: Stack(
        clipBehavior: Clip.none,
        children: reactions.mapIndexed((i, e) => Positioned(
          top: 0,
          left: !widget.message.isFromMe! ? null : -i * 2.0,
          right: widget.message.isFromMe! ? null : -i * 2.0,
          child: ReactionWidget(
            messageIsFromMe: widget.message.isFromMe!,
            reactionIsFromMe: e.isFromMe!,
            reactionType: e.associatedMessageType!,
          ),
        )).toList().reversed.toList(),
      ),
    );
  }
}