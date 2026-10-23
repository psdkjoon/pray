abstract class AppInfo {
  static const String name = 'Pray';
  static const String packageName = 'pray';
  static const String version = '2.0.0';
  static const String author = 'Hossein';

  static const String githubHandle = 'psdkjoon';
  static const String repoName = 'pray';
  static const String githubUrl = 'https://github.com/$githubHandle';
  static const String githubDisplay = 'github.com/$githubHandle';
  static const String repoUrl = '$githubUrl/$repoName';
  static const String repoDisplay = 'github.com/$githubHandle/$repoName';

  static const String telegramHandle = 'psdkjoon';
  static const String telegramUrl = 'https://t.me/$telegramHandle';
  static const String telegramDisplay = '@$telegramHandle';

  static const String donateIranUrl = 'https://daramet.com/psdkjoon';
  static const String donateIranDisplay = 'daramet.com/psdkjoon';

  static const List<CryptoWallet> wallets = <CryptoWallet>[
    CryptoWallet(
      coin: 'Bitcoin',
      asset: 'assets/icons/coins/btc.svg',
      network: 'Bitcoin network',
      address: 'bc1q2p72az3e09zmq7nj3pydamv3rcav070c7yck0h',
    ),
    CryptoWallet(
      coin: 'USDT',
      asset: 'assets/icons/coins/usdt.svg',
      network: 'TRON network (TRC-20)',
      address: 'TSemVbsVbZw6MeAUSfBBLPAadxSw18RYHd',
    ),
    CryptoWallet(
      coin: 'USDC',
      asset: 'assets/icons/coins/usdc.svg',
      network: 'Base network',
      address: '0x3692C9Dc9e8984D6399C74B2454d1Cf5A90bD1E4',
    ),
  ];

  static const String linuxPackageName = 'ir.psdkjoon.pray';

  static const bool usesNotifications = true;

  static const bool usesBackground = true;
}

class CryptoWallet {
  const CryptoWallet({
    required this.coin,
    required this.asset,
    required this.network,
    required this.address,
  });

  final String coin;

  final String asset;

  final String network;
  final String address;
}
