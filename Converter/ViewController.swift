import UIKit

enum Currency: String {
    case EUR, GBP
}

enum NetworkError: Error {
    case serverError
    case invalidData
}

protocol RatesProvider {
    func fetchRate(for currency: Currency, completion: @escaping (Result<Double, Error>) -> Void)
}

class NetworkRatesService: RatesProvider {
    func fetchRate(for currency: Currency, completion: @escaping (Result<Double, Error>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            let rate = (currency == .EUR) ? 0.92 : 0.78
            completion(.success(rate))
        }
    }
}

class ConverterViewModel {
    
    private let ratesProvider: RatesProvider
    
    var amountText: String = ""
    var selectedCurrencyIndex: Int = 0 // 0 = EUR, 1 = GBP
    
    var onLoadingStateChange: ((Bool) -> Void)?
    var onResultUpdate: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    init(ratesProvider: RatesProvider = NetworkRatesService()) {
        self.ratesProvider = ratesProvider
    }
    
    func convertTapped() {
        guard let amount = Double(amountText), (0...100000).contains(amount) else {
            onError?("Please enter amount from 0 to 100000.")
            return
        }
        
        let targetCurrency: Currency = (selectedCurrencyIndex == 0) ? .EUR : .GBP
        
        onLoadingStateChange?(true)
        
        ratesProvider.fetchRate(for: targetCurrency) { [weak self] result in
            DispatchQueue.main.async {
                self?.onLoadingStateChange?(false)
                switch result {
                case .success(let rate):
                    let resultValue = amount * rate
                    let formattedResult = String(format: "Result: %.2f %@", resultValue, targetCurrency.rawValue)
                    self?.onResultUpdate?(formattedResult)
                case .failure:
                    self?.onError?("Failed to fetch rates. Try again.")
                }
            }
        }
    }
}

class ViewController: UIViewController {
    
    private var viewModel = ConverterViewModel()
    
    // MARK: - UI Elements
    private let amountTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter amount in USD"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .decimalPad
        tf.accessibilityIdentifier = AccessibilityID.amountTextField
        return tf
    }()
    
    private let currencySegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["EUR", "GBP"])
        sc.selectedSegmentIndex = 0
        sc.accessibilityIdentifier = AccessibilityID.currencySelector
        return sc
    }()
    
    private let convertButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Convert", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.accessibilityIdentifier = AccessibilityID.convertButton
        return btn
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.text = "Result will appear here"
        label.textAlignment = .center
        label.accessibilityIdentifier = AccessibilityID.resultLabel
        return label
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.accessibilityIdentifier = AccessibilityID.loadingIndicator
        return indicator
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        bindViewModel()
        
        convertButton.addTarget(self, action: #selector(didTapConvert), for: .touchUpInside)
    }
    
    // MARK: - Setup
    private func bindViewModel() {
        viewModel.onLoadingStateChange = { [weak self] isLoading in
            isLoading ? self?.loadingIndicator.startAnimating() : self?.loadingIndicator.stopAnimating()
            self?.convertButton.isEnabled = !isLoading
        }
        
        viewModel.onResultUpdate = { [weak self] resultText in
            self?.resultLabel.text = resultText
            self?.resultLabel.textColor = .black
        }
        
        viewModel.onError = { [weak self] errorText in
            self?.resultLabel.text = errorText
            self?.resultLabel.textColor = .red
        }
    }
    
    @objc private func didTapConvert() {
        viewModel.amountText = amountTextField.text ?? ""
        viewModel.selectedCurrencyIndex = currencySegmentedControl.selectedSegmentIndex
        
        viewModel.convertTapped()
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [amountTextField, currencySegmentedControl, convertButton, loadingIndicator, resultLabel])
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 300)
        ])
    }
}

