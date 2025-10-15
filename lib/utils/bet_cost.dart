/// 复式注数与费用计算工具
/// 规则：
/// - 双色球：前区需至少选6个，后区至少选1个。注数 = C(redCount,6) * C(blueCount,1)
/// - 大乐透：前区需至少选5个，后区至少选2个。注数 = C(frontCount,5) * C(backCount,2)
/// 单注价格：2 元
library;

class BetCost {
  const BetCost({required this.bets});

  final int bets;

  int get totalYuan => bets * 2;
}

BigInt _combBigInt(int n, int k) {
  if (k < 0 || k > n) return BigInt.zero;
  k = k > n - k ? n - k : k;
  BigInt numer = BigInt.one;
  BigInt denom = BigInt.one;
  for (var i = 0; i < k; i++) {
    numer *= BigInt.from(n - i);
    denom *= BigInt.from(i + 1);
  }
  return numer ~/ denom;
}

int _comb(int n, int k) => _combBigInt(n, k).toInt();

BetCost calculateShuangSeQiuCost({required int redCount, required int blueCount}) {
  if (redCount < 6 || blueCount < 1) return const BetCost(bets: 0);
  final bets = _comb(redCount, 6) * _comb(blueCount, 1);
  return BetCost(bets: bets);
}

BetCost calculateDaLeTouCost({required int frontCount, required int backCount}) {
  if (frontCount < 5 || backCount < 2) return const BetCost(bets: 0);
  final bets = _comb(frontCount, 5) * _comb(backCount, 2);
  return BetCost(bets: bets);
}
