import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class TelegramLauncher {
  static Future<bool> openBotChat({String? startParam}) async {
    final botName = ApiConfig.telegramBotUsername;
    final paramPart = (startParam != null && startParam.isNotEmpty) ? '?start=$startParam' : '';
    
    final tgUri = Uri.parse('tg://resolve?domain=$botName$paramPart');
    final webUri = Uri.parse('https://t.me/$botName$paramPart');

    try {
      if (await canLaunchUrl(tgUri)) {
        return await launchUrl(tgUri);
      } else {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<bool> openChannel() async {
    final channelName = ApiConfig.telegramChannelUsername;
    final tgUri = Uri.parse('tg://resolve?domain=$channelName');
    final webUri = Uri.parse('https://t.me/$channelName');

    if (await canLaunchUrl(tgUri)) {
      return await launchUrl(tgUri);
    } else {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
