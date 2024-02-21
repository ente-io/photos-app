import 'dart:io';

import 'package:collection/collection.dart' show IterableNullableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logging/logging.dart';
import 'package:photos/ente_theme_data.dart';
import "package:photos/generated/l10n.dart";
import 'package:photos/models/subscription.dart';
import 'package:photos/services/billing_service.dart';
import 'package:photos/services/user_service.dart';
import 'package:photos/ui/common/loading_widget.dart';
import 'package:photos/ui/common/progress_dialog.dart';
import 'package:photos/utils/dialog_util.dart';

class PaymentWebPage extends StatefulWidget {
  final String? planId;
  final String? actionType;

  const PaymentWebPage({Key? key, this.planId, this.actionType})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _PaymentWebPageState();
}

class _PaymentWebPageState extends State<PaymentWebPage> {
  final _logger = Logger("PaymentWebPageState");
  final UserService userService = UserService.instance;
  final BillingService billingService = BillingService.instance;
  final String basePaymentUrl = kWebPaymentBaseEndpoint;
  late ProgressDialog _dialog;
  InAppWebViewController? webView;
  double progress = 0;
  Uri? initPaymentUrl;

  @override
  void initState() {
    userService.getPaymentToken().then((token) {
      initPaymentUrl = _getPaymentUrl(token);
      setState(() {});
    });
    if (Platform.isAndroid && kDebugMode) {
      AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _dialog = createProgressDialog(
      context,
      S.of(context).pleaseWait,
      isDismissible: true,
    );
    if (initPaymentUrl == null) {
      return const EnteLoadingWidget();
    }
    return WillPopScope(
      onWillPop: (() async => _buildPageExitWidget(context)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).subscription),
        ),
        body: Column(
          children: <Widget>[
            (progress != 1.0)
                ? LinearProgressIndicator(value: progress)
                : const SizedBox.shrink(),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: initPaymentUrl),
                onProgressChanged:
                    (InAppWebViewController controller, int progress) {
                  setState(() {
                    this.progress = progress / 100;
                  });
                },
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    useShouldOverrideUrlLoading: true,
                  ),
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final loadingUri = navigationAction.request.url;
                  _logger.info("Loading url $loadingUri");
                  // handle the payment response
                  if (_isPaymentActionComplete(loadingUri)) {
                    await _handlePaymentResponse(loadingUri!);
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onConsoleMessage: (controller, consoleMessage) {
                  _logger.info(consoleMessage);
                },
                onLoadStart: (controller, navigationAction) async {
                  if (!_dialog.isShowing()) {
                    await _dialog.show();
                  }
                },
                onLoadError: (controller, navigationAction, code, msg) async {
                  if (_dialog.isShowing()) {
                    await _dialog.hide();
                  }
                },
                onLoadHttpError:
                    (controller, navigationAction, code, msg) async {
                  _logger.info("onHttpError with $code and msg = $msg");
                },
                onLoadStop: (controller, navigationAction) async {
                  _logger.info("loadStart" + navigationAction.toString());
                  if (_dialog.isShowing()) {
                    await _dialog.hide();
                  }
                },
              ),
            ),
          ].whereNotNull().toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dialog.hide();
    super.dispose();
  }

  Uri _getPaymentUrl(String? paymentToken) {
    final queryParameters = {
      'productID': widget.planId,
      'paymentToken': paymentToken,
      'action': widget.actionType,
      'redirectURL': kWebPaymentRedirectUrl,
    };
    final tryParse = Uri.tryParse(kWebPaymentBaseEndpoint);
    if (kDebugMode && kWebPaymentBaseEndpoint.startsWith("http://")) {
      return Uri.http(tryParse!.authority, tryParse.path, queryParameters);
    } else {
      return Uri.https(tryParse!.authority, tryParse.path, queryParameters);
    }
  }

  // show dialog to handle accidental back press.
  Future<bool> _buildPageExitWidget(BuildContext context) async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).areYouSureYouWantToExit),
        actions: <Widget>[
          TextButton(
            child: Text(
              S.of(context).yes,
              style: const TextStyle(
                color: Colors.redAccent,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          TextButton(
            child: Text(
              S.of(context).no,
              style: TextStyle(
                color: Theme.of(context).colorScheme.greenAlternative,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
    if (result != null) {
      return result;
    }
    return false;
  }

  bool _isPaymentActionComplete(Uri? loadingUri) {
    return loadingUri.toString().startsWith(kWebPaymentRedirectUrl);
  }

  Future<void> _handlePaymentResponse(Uri uri) async {
    final queryParams = uri.queryParameters;
    final paymentStatus = uri.queryParameters['status'] ?? '';
    _logger.fine('handle payment response with status $paymentStatus');
    if (paymentStatus == 'success') {
      await _handlePaymentSuccess(queryParams);
    } else if (paymentStatus == 'fail') {
      final reason = queryParams['reason'] ?? '';
      await _handlePaymentFailure(reason);
    } else {
      // should never reach here
      _logger.severe("unexpected status", uri.toString());
      await showGenericErrorDialog(
        context: context,
        error: Exception("expected payment status $paymentStatus"),
      );
    }
  }

  Future<void> _handlePaymentFailure(String reason) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).paymentFailed),
        content: Text(S.of(context).paymentFailedWithReason(reason)),
        actions: <Widget>[
          TextButton(
            child: Text(S.of(context).ok),
            onPressed: () {
              Navigator.of(context).pop('dialog');
            },
          ),
        ],
      ),
    );
    Navigator.of(context).pop(true);
  }

  // return true if verifySubscription didn't throw any exceptions
  Future<void> _handlePaymentSuccess(Map<String, String> queryParams) async {
    final checkoutSessionID = queryParams['session_id'] ?? '';
    await _dialog.show();
    try {
      // ignore: unused_local_variable
      final response = await billingService.verifySubscription(
        widget.planId,
        checkoutSessionID,
        paymentProvider: stripe,
      );
      await _dialog.hide();
      final content = widget.actionType == 'buy'
          ? S.of(context).yourPurchaseWasSuccessful
          : S.of(context).yourSubscriptionWasUpdatedSuccessfully;
      await _showExitPageDialog(
        title: S.of(context).thankYou,
        content: content,
      );
    } catch (error) {
      _logger.severe(error);
      await _dialog.hide();
      await _showExitPageDialog(
        title: S.of(context).failedToVerifyPaymentStatus,
        content: S.of(context).pleaseWaitForSometimeBeforeRetrying,
      );
    }
  }

  // warn the user to wait for sometime before trying another payment
  Future<dynamic> _showExitPageDialog({String? title, String? content}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title!),
        content: Text(content!),
        actions: <Widget>[
          TextButton(
            child: Text(
              S.of(context).ok,
              style: TextStyle(
                color: Theme.of(context).colorScheme.greenAlternative,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop('dialog');
            },
          ),
        ],
      ),
    ).then((val) => Navigator.pop(context, true));
  }
}
