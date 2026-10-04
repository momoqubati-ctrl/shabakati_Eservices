import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bas_pay_flutter/bas_pay_flutter.dart';
import 'package:bas_pay_flutter/models/init_bas_sdk_model.dart';
import '../config/api_config.dart';

/// نتيجة عملية الدفع عبر بوابة BasGate
class BasGatePaymentResult {
  final bool isSuccess;
  final bool isCancelled;
  final String message;
  final String? paymentId;
  final String? paymentReference;
  final String? paymentMethod;
  final String? walletName;
  final String? orderId;
  final String? trxToken;
  final int? statusCode;
  final Map<String, dynamic>? rawResponse;

  const BasGatePaymentResult({
    required this.isSuccess,
    this.isCancelled = false,
    required this.message,
    this.paymentId,
    this.paymentReference,
    this.paymentMethod,
    this.walletName,
    this.orderId,
    this.trxToken,
    this.statusCode,
    this.rawResponse,
  });

  @override
  String toString() {
    return 'BasGatePaymentResult(isSuccess: $isSuccess, isCancelled: $isCancelled, message: $message, paymentId: $paymentId, paymentReference: $paymentReference, walletName: $walletName, orderId: $orderId)';
  }
}

/// خدمة الدفع الإلكتروني المباشر عبر بوابة BasGate (المحافظ والبنوك اليمنية)
class BasGatePaymentService {
  final Dio _dio;

  BasGatePaymentService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                validateStatus: (status) => status != null && status < 500,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  /// بدء عملية الدفع عبر البوابة الإلكترونية
  Future<BasGatePaymentResult> payWithBasGate({
    required BuildContext context,
    required double amountYer,
    required String orderId,
    String? userAccount,
    String? customerName,
    String? customerPhone,
    String? description,
    List<Map<String, dynamic>>? items,
  }) async {
    String? createdPaymentId;
    String? trxToken;

    try {
      // 1. طلب إنشاء الجلسة وتوليد trxToken من السيرفر الخلفي
      final initiateUrl = '${ApiConfig.vercelBackendUrl}/api/basgate-initiate';

      final initiatePayload = {
        'amount': amountYer,
        'currency': 'YER',
        'order_id': orderId,
        'user_account': userAccount ?? customerPhone ?? '777000000',
        'customer_name': customerName ?? 'عميل شبكتي',
        'customer_phone': customerPhone,
        'description': description ?? 'شراء من تطبيق شبكتي للخدمات الإلكترونية',
        'items': items,
      };

      final initRes = await _dio.post(initiateUrl, data: initiatePayload);

      final initData = (initRes.data is Map<String, dynamic>)
          ? initRes.data as Map<String, dynamic>
          : <String, dynamic>{};

      if (initRes.statusCode != 200 || initData['success'] != true) {
        final errMsg = initData['error']?.toString() ?? 'تعذر بدء عملية الدفع مع البوابة';
        return BasGatePaymentResult(
          isSuccess: false,
          message: errMsg,
          rawResponse: initData,
        );
      }

      trxToken = initData['trx_token']?.toString();
      createdPaymentId = initData['payment_id']?.toString();
      final env = initData['environment']?.toString() ?? 'prod';
      final isProd = env == 'prod' || env == 'live';

      if (trxToken == null || trxToken.isEmpty) {
        return BasGatePaymentResult(
          isSuccess: false,
          paymentId: createdPaymentId,
          orderId: orderId,
          message: 'لم يتم استلام رمز المعاملة (trxToken) من الخادم.',
        );
      }

      // 2. إعداد نموذج الـ SDK بناءً على بيئة التشغيل (دون تعبئة رقم الهاتف مسبقاً في بوابة الدفع)
      final InitBasSdkModel sdkModel = isProd
          ? InitBasSdkModel.prod(
              trxToken: trxToken,
              userIdentifier: null,
              fullName: customerName ?? 'عميل شبكتي',
              language: 'ar',
              product: null,
            )
          : InitBasSdkModel.dev(
              trxToken: trxToken,
              userIdentifier: null,
              fullName: customerName ?? 'عميل شبكتي',
              language: 'ar',
              product: null,
            );

      // 3. فتح شاشة الدفع الخاصة بـ BasGate Native SDK
      debugPrint('[BasGate] Calling SDK in environment=$env');
      final result = await BasPayFlutter().callBasPay(model: sdkModel);
      final bool resultStatus = result.resultStatus;
      final resultModel = result.resultModel;

      debugPrint('[BasGate] SDK returned status=$resultStatus, code=${resultModel?.code}, msg=${resultModel?.message}');

      final bool isSdkSuccess = resultStatus && (resultModel?.status == true);
      final int? sdkCode = resultModel?.code;
      final String? sdkMessage = resultModel?.message;

      // فحص إذا تراجع المستخدم يدوياً
      final bool isUserCancelled = sdkCode == 602 ||
          (sdkMessage?.toLowerCase().contains('cancel') ?? false) ||
          (sdkMessage?.toLowerCase().contains('dismiss') ?? false) ||
          (sdkMessage?.contains('إلغاء') ?? false) ||
          (sdkMessage?.contains('تراجع') ?? false);

      // 4. التحقق الخادمي الصارم مع سيرفر BasGate
      final verifyUrl = '${ApiConfig.vercelBackendUrl}/api/basgate-verify';
      final verifyRes = await _dio.post(verifyUrl, data: {
        'payment_id': createdPaymentId,
        'order_id': orderId,
        'sdk_result_status': isSdkSuccess,
        'sdk_message': sdkMessage,
      });

      final verifyData = (verifyRes.data is Map<String, dynamic>)
          ? verifyRes.data as Map<String, dynamic>
          : <String, dynamic>{};

      final bool isAuthoritativeSuccess = verifyData['success'] == true || verifyData['outcome'] == 'SUCCESS';
      final String outcome = verifyData['outcome']?.toString() ?? (isAuthoritativeSuccess ? 'SUCCESS' : 'FAILED');
      final String? paymentReference = verifyData['payment_reference']?.toString() ?? createdPaymentId;
      final String paymentMethod = verifyData['payment_method']?.toString() ?? 'المحافظ الإلكترونية';
      final String? walletName = verifyData['wallet_name']?.toString();

      if (isAuthoritativeSuccess) {
        return BasGatePaymentResult(
          isSuccess: true,
          message: 'تم تأكيد عملية الدفع بنجاح.',
          paymentId: createdPaymentId,
          paymentReference: paymentReference,
          paymentMethod: paymentMethod,
          walletName: walletName,
          orderId: orderId,
          trxToken: trxToken,
          statusCode: 1202,
          rawResponse: verifyData,
        );
      }

      if (isUserCancelled || outcome == 'CANCELLED') {
        return BasGatePaymentResult(
          isSuccess: false,
          isCancelled: true,
          message: 'تم إلغاء عملية الدفع. لم يتم خصم أي مبلغ من حسابك.',
          paymentId: createdPaymentId,
          orderId: orderId,
          trxToken: trxToken,
          rawResponse: verifyData,
        );
      }

      return BasGatePaymentResult(
        isSuccess: false,
        message: verifyData['message']?.toString() ?? sdkMessage ?? 'تعثر إتمام عملية الدفع.',
        paymentId: createdPaymentId,
        orderId: orderId,
        trxToken: trxToken,
        statusCode: sdkCode,
        rawResponse: verifyData,
      );
    } catch (e) {
      debugPrint('[BasGate] Exception during payment: $e');
      String friendlyMsg = 'حدث خطأ أثناء الاتصال ببوابة الدفع، يرجى التحقق من اتصال الإنترنت والمحاولة مجدداً.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          friendlyMsg = data['error'].toString();
        }
      }
      return BasGatePaymentResult(
        isSuccess: false,
        paymentId: createdPaymentId,
        orderId: orderId,
        trxToken: trxToken,
        message: friendlyMsg,
      );
    }
  }
}
