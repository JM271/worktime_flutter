class BankDetails {
  const BankDetails({
    this.accountHolder = '',
    this.accountNumber = '',
    this.bankName = '',
    this.bic = '',
    this.country = '',
    this.currency = '',
  });

  final String accountHolder;
  final String accountNumber;
  final String bankName;
  final String bic;
  final String country;
  final String currency;

  bool get isEmpty => fields.isEmpty;

  List<(String, String)> get fields => [
    if (accountHolder.trim().isNotEmpty)
      ('Account holder', accountHolder.trim()),
    if (bankName.trim().isNotEmpty) ('Bank', bankName.trim()),
    if (accountNumber.trim().isNotEmpty)
      ('IBAN / Account number', accountNumber.trim()),
    if (country.trim().isNotEmpty) ('Country', country.trim()),
    if (currency.trim().isNotEmpty) ('Currency', currency.trim()),
    if (bic.trim().isNotEmpty) ('BIC / SWIFT', bic.trim()),
  ];

  Map<String, String> toJson() => {
    'accountHolder': accountHolder.trim(),
    'accountNumber': accountNumber.trim(),
    'bankName': bankName.trim(),
    'bic': bic.trim(),
    'country': country.trim(),
    'currency': currency.trim(),
  };

  factory BankDetails.fromJson(Map<String, dynamic> json) => BankDetails(
    accountHolder: json['accountHolder'] as String? ?? '',
    accountNumber: json['accountNumber'] as String? ?? '',
    bankName: json['bankName'] as String? ?? '',
    bic: json['bic'] as String? ?? '',
    country: json['country'] as String? ?? '',
    currency: json['currency'] as String? ?? '',
  );
}

const defaultBankDetails = BankDetails(
  accountHolder: 'Jonas Christoph Mühle',
  bankName: 'PostFinance AG',
  accountNumber: 'CH31 0900 0000 1486 7662 9',
  country: 'Switzerland',
  currency: 'CHF',
  bic: 'POFICHBEXXX',
);
