import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:photos/core/configuration.dart';
import "package:photos/generated/l10n.dart";
import "package:photos/models/api/collection/user.dart";
import 'package:photos/models/collection/collection.dart';
import 'package:photos/services/collections_service.dart';
import "package:photos/services/user_service.dart";
import 'package:photos/theme/ente_theme.dart';
import 'package:photos/ui/actions/collection/collection_sharing_actions.dart';
import 'package:photos/ui/components/buttons/button_widget.dart';
import 'package:photos/ui/components/captioned_text_widget.dart';
import 'package:photos/ui/components/divider_widget.dart';
import 'package:photos/ui/components/menu_item_widget/menu_item_widget.dart';
import 'package:photos/ui/components/menu_section_description_widget.dart';
import 'package:photos/ui/components/menu_section_title.dart';
import 'package:photos/ui/components/models/button_type.dart';
import 'package:photos/ui/sharing/user_avator_widget.dart';
import "package:photos/ui/sharing/verify_identity_dialog.dart";
import "package:photos/utils/dialog_util.dart";

class AddParticipantPage extends StatefulWidget {
  final Collection collection;
  final bool isAddingViewer;

  const AddParticipantPage(this.collection, this.isAddingViewer, {super.key});

  @override
  State<StatefulWidget> createState() => _AddParticipantPage();
}

class _AddParticipantPage extends State<AddParticipantPage> {
  String selectedEmail = '';
  String _email = '';
  bool isEmailListEmpty = false;
  bool _emailIsValid = false;
  bool isKeypadOpen = false;
  late CollectionActions collectionActions;

  // Focus nodes are necessary
  final textFieldFocusNode = FocusNode();
  final _textController = TextEditingController();

  @override
  void initState() {
    collectionActions = CollectionActions(CollectionsService.instance);
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isKeypadOpen = MediaQuery.of(context).viewInsets.bottom > 100;
    final enteTextTheme = getEnteTextTheme(context);
    final enteColorScheme = getEnteColorScheme(context);
    final List<User> suggestedUsers = _getSuggestedUser();
    isEmailListEmpty = suggestedUsers.isEmpty;
    return Scaffold(
      resizeToAvoidBottomInset: isKeypadOpen,
      appBar: AppBar(
        title: Text(
          widget.isAddingViewer
              ? S.of(context).addViewer
              : S.of(context).addCollaborator,
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              S.of(context).addANewEmail,
              style: enteTextTheme.small
                  .copyWith(color: enteColorScheme.textMuted),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _getEmailField(),
          ),
          (isEmailListEmpty && widget.isAddingViewer)
              ? const Expanded(child: SizedBox.shrink())
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        !isEmailListEmpty
                            ? MenuSectionTitle(
                                title: S.of(context).orPickAnExistingOne,
                              )
                            : const SizedBox.shrink(),
                        Expanded(
                          child: ListView.builder(
                            itemBuilder: (context, index) {
                              if (index >= suggestedUsers.length) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: MenuSectionDescriptionWidget(
                                    content: S
                                        .of(context)
                                        .collaboratorsCanAddPhotosAndVideosToTheSharedAlbum,
                                  ),
                                );
                              }
                              final currentUser = suggestedUsers[index];
                              return Column(
                                children: [
                                  MenuItemWidget(
                                    captionedTextWidget: CaptionedTextWidget(
                                      title: currentUser.email,
                                    ),
                                    leadingIconSize: 24.0,
                                    leadingIconWidget: UserAvatarWidget(
                                      currentUser,
                                      type: AvatarType.mini,
                                    ),
                                    menuItemColor:
                                        getEnteColorScheme(context).fillFaint,
                                    pressedColor:
                                        getEnteColorScheme(context).fillFaint,
                                    trailingIcon:
                                        (selectedEmail == currentUser.email)
                                            ? Icons.check
                                            : null,
                                    onTap: () async {
                                      textFieldFocusNode.unfocus();
                                      if (selectedEmail == currentUser.email) {
                                        selectedEmail = '';
                                      } else {
                                        selectedEmail = currentUser.email;
                                      }

                                      setState(() => {});
                                      // showShortToast(context, "yet to implement");
                                    },
                                    isTopBorderRadiusRemoved: index > 0,
                                    isBottomBorderRadiusRemoved:
                                        index < (suggestedUsers.length - 1),
                                  ),
                                  (index == (suggestedUsers.length - 1))
                                      ? const SizedBox.shrink()
                                      : DividerWidget(
                                          dividerType: DividerType.menu,
                                          bgColor: getEnteColorScheme(context)
                                              .fillFaint,
                                        ),
                                ],
                              );
                            },
                            itemCount: suggestedUsers.length +
                                (widget.isAddingViewer ? 0 : 1),
                            // physics: const ClampingScrollPhysics(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: 16,
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  ButtonWidget(
                    buttonType: ButtonType.primary,
                    buttonSize: ButtonSize.large,
                    labelText: widget.isAddingViewer
                        ? S.of(context).addViewer
                        : S.of(context).addCollaborator,
                    isDisabled: (selectedEmail == '' && !_emailIsValid),
                    onTap: (selectedEmail == '' && !_emailIsValid)
                        ? null
                        : () async {
                            final emailToAdd =
                                selectedEmail == '' ? _email : selectedEmail;
                            final result =
                                await collectionActions.addEmailToCollection(
                              context,
                              widget.collection,
                              emailToAdd,
                              widget.isAddingViewer
                                  ? CollectionParticipantRole.viewer
                                  : CollectionParticipantRole.collaborator,
                            );
                            if (result && mounted) {
                              Navigator.of(context).pop(true);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      if ((selectedEmail == '' && !_emailIsValid)) {
                        await showErrorDialog(
                          context,
                          S.of(context).invalidEmailAddress,
                          S.of(context).enterValidEmail,
                        );
                        return;
                      }
                      final emailToAdd =
                          selectedEmail == '' ? _email : selectedEmail;
                      // ignore: unawaited_futures
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return VerifyIdentifyDialog(
                            self: false,
                            email: emailToAdd,
                          );
                        },
                      );
                    },
                    child: Text(
                      S.of(context).verifyIDLabel,
                      textAlign: TextAlign.center,
                      style: enteTextTheme.smallMuted.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void clearFocus() {
    _textController.clear();
    _email = _textController.text;
    _emailIsValid = false;
    textFieldFocusNode.unfocus();
    setState(() => {});
  }

  Widget _getEmailField() {
    return TextFormField(
      controller: _textController,
      focusNode: textFieldFocusNode,
      style: getEnteTextTheme(context).body,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
          borderSide:
              BorderSide(color: getEnteColorScheme(context).strokeMuted),
        ),
        fillColor: getEnteColorScheme(context).fillFaint,
        filled: true,
        hintText: S.of(context).enterEmail,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(4),
        ),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: getEnteColorScheme(context).strokeMuted,
        ),
        suffixIcon: _email == ''
            ? null
            : IconButton(
                onPressed: clearFocus,
                icon: Icon(
                  Icons.cancel,
                  color: getEnteColorScheme(context).strokeMuted,
                ),
              ),
      ),
      onChanged: (value) {
        if (selectedEmail != '') {
          selectedEmail = '';
        }
        _email = value.trim();
        _emailIsValid = EmailValidator.validate(_email);
        setState(() {});
      },
      autocorrect: false,
      keyboardType: TextInputType.emailAddress,
      //initialValue: _email,
      textInputAction: TextInputAction.next,
    );
  }

  List<User> _getSuggestedUser() {
    final List<User> suggestedUsers = [];
    final Set<String> existingEmails = {};
    final int ownerID = Configuration.instance.getUserID()!;
    existingEmails.add(Configuration.instance.getEmail()!);
    for (final User? u in widget.collection.sharees ?? []) {
      if (u != null && u.id != null && u.email.isNotEmpty) {
        existingEmails.add(u.email);
      }
    }
    for (final c in CollectionsService.instance.getActiveCollections()) {
      if (c.owner?.id == ownerID) {
        for (final User? u in c.sharees ?? []) {
          if (u != null &&
              u.id != null &&
              u.email.isNotEmpty &&
              !existingEmails.contains(u.email)) {
            existingEmails.add(u.email);
            suggestedUsers.add(u);
          }
        }
      } else if (c.owner != null &&
          c.owner!.id != null &&
          c.owner!.email.isNotEmpty &&
          !existingEmails.contains(c.owner!.email)) {
        existingEmails.add(c.owner!.email);
        suggestedUsers.add(c.owner!);
      }
    }
    final cachedUserDetails = UserService.instance.getCachedUserDetails();
    if (cachedUserDetails != null &&
        (cachedUserDetails.familyData?.members?.isNotEmpty ?? false)) {
      for (final member in cachedUserDetails.familyData!.members!) {
        if (!existingEmails.contains(member.email)) {
          existingEmails.add(member.email);
          suggestedUsers.add(User(email: member.email));
        }
      }
    }
    if (_textController.text.trim().isNotEmpty) {
      suggestedUsers.removeWhere(
        (element) => !element.email
            .toLowerCase()
            .contains(_textController.text.trim().toLowerCase()),
      );
    }
    suggestedUsers.sort((a, b) => a.email.compareTo(b.email));

    return suggestedUsers;
  }
}
