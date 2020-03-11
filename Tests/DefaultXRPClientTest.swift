import SwiftGRPC
import XCTest
@testable import XpringKit

final class DefaultXRPClientTest: XCTestCase {
  // Codes which are failures returned from the ledger.
  private static let transactionStatusFailureCodes = [
    "tefFAILURE", "tecCLAIM", "telBAD_PUBLIC_KEY", "temBAD_FEE", "terRETRY"
  ]

  // MARK: - Balance
  func testGetBalanceWithSuccess() {
    // GIVEN an XRPClient which will successfully return a balance from a mocked network call.
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN the balance is requested.
    guard let balance = try? xrpClient.getBalance(for: .testAddress) else {
      XCTFail("Exception should not be thrown when trying to get a balance")
      return
    }

    // THEN the balance is correct.
    XCTAssertEqual(balance, .testBalance)
  }

  func testGetBalanceWithClassicAddress() {
    // GIVEN a classic address.
    guard let classicAddressComponents = Utils.decode(xAddress: .testAddress) else {
      XCTFail("Failed to decode X-Address.")
      return
    }
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN the balance is requested THEN an error is thrown.
    XCTAssertThrowsError(
      try xrpClient.getBalance(for: classicAddressComponents.classicAddress),
      "Exception not thrown"
    ) { error in
      guard
        case .invalidInputs = error as? XRPLedgerError
        else {
          XCTFail("Error thrown was not invalid inputs error")
          return
      }

    }
  }

  func testGetBalanceWithFailure() {
    // GIVEN an XRPClient client which will throw an error when a balance is requested.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .failure(XpringKitTestError.mockFailure),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the balance is requested THEN the error is thrown.
    XCTAssertThrowsError(try xrpClient.getBalance(for: .testAddress), "Exception not thrown") { error in
      guard
        let _ = error as? XpringKitTestError
        else {
          XCTFail("Error thrown was not mocked error")
          return
      }
    }
  }

  // MARK: - Send
  func testSendWithSuccess() {
    // GIVEN an XRPClient client which will successfully return a balance from a mocked network call.
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN XRP is sent.
    guard
      let transactionHash = try? xrpClient.send(
        .testSendAmount,
        to: .testAddress,
        from: .testWallet)
      else {
        XCTFail("Exception should not be thrown when trying to send XRP")
        return
    }

    // THEN the engine result code is as expected.
    XCTAssertEqual(transactionHash, TransactionHash.testTransactionHash)
  }

  func testSendWithClassicAddress() {
    // GIVEN a classic address.
    guard let classicAddressComponents = Utils.decode(xAddress: .testAddress) else {
      XCTFail("Failed to decode X - Address.")
      return
    }
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN XRP is sent to a classic address THEN an error is thrown.
    XCTAssertThrowsError(try xrpClient.send(
      .testSendAmount,
      to: classicAddressComponents.classicAddress,
      from: .testWallet
      ))
  }

  func testSendWithInvalidAddress() {
    // GIVEN an XRPClient client and an invalid destination address.
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)
    let destinationAddress = "xrp"

    // WHEN XRP is sent to an invalid address THEN an error is thrown.
    XCTAssertThrowsError(try xrpClient.send(
      .testSendAmount,
      to: destinationAddress,
      from: .testWallet
      ))
  }

  func testSendWithAccountInfoFailure() {
    // GIVEN an XRPClient client which will fail to return account info.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .failure(XpringKitTestError.mockFailure),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN a send is attempted then an error is thrown.
    XCTAssertThrowsError(try xrpClient.send(
      .testSendAmount,
      to: .testAddress,
      from: .testWallet
      ))
  }

  func testSendWithFeeFailure() {
    // GIVEN an XRPClient client which will fail to return a fee.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .failure(XpringKitTestError.mockFailure),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN a send is attempted then an error is thrown.
    XCTAssertThrowsError(try xrpClient.send(
      .testSendAmount,
      to: .testAddress,
      from: .testWallet
      ))
  }

  func testSendWithSubmitFailure() {
    // GIVEN an XRPClient client which will fail to submit a transaction.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .failure(XpringKitTestError.mockFailure),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN a send is attempted then an error is thrown.
    XCTAssertThrowsError(try xrpClient.send(
      .testSendAmount,
      to: .testAddress,
      from: .testWallet
      ))
  }

  // MARK: - Transaction Status
  func testGetTransactionStatusWithUnvalidatedTransactionAndFailureCode() {
    // Iterate over different types of transaction status codes which represent failures.
    for transactionStatusCodeFailure in DefaultXRPClientTest.transactionStatusFailureCodes {
      // GIVEN an XRPClient which returns an unvalidated transaction and a failed transaction status code.
      let transactionStatusResponse = makeGetTransactionResponse(
        validated: false,
        resultCode: transactionStatusCodeFailure
      )
      let networkClient = FakeNetworkClient(
        accountInfoResult: .success(.testGetAccountInfoResponse),
        feeResult: .success(.testGetFeeResponse),
        submitTransactionResult: .success(.testSubmitTransactionResponse),
        transactionStatusResult: .success(transactionStatusResponse),
        transactionHistoryResult: .success(.testTransactionHistoryResponse)
      )
      let xrpClient = DefaultXRPClient(networkClient: networkClient)

      // WHEN the transaction status is retrieved.
      let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

      // THEN the transaction status is pending.
      XCTAssertEqual(transactionStatus, .pending)
    }
  }

  func testGetTransactionStatusWithUnvalidatedTransactionAndSuccessCode() {
    // GIVEN an XRPClient which returns an unvalidated transaction and a succeeded transaction status code.
    let transactionStatusResponse = makeGetTransactionResponse(
      validated: false,
      resultCode: .testTransactionStatusCodeSuccess
    )
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(transactionStatusResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the transaction status is retrieved.
    let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

    // THEN the transaction status is pending.
    XCTAssertEqual(transactionStatus, .pending)
  }

  func testGetTransactionStatusWithValidatedTransactionAndFailureCode() {
    // Iterate over different types of transaction status codes which represent failures.
    for transactionStatusCodeFailure in DefaultXRPClientTest.transactionStatusFailureCodes {
      // GIVEN an XRPClient which returns an unvalidated transaction and a failed transaction status code.
      let transactionStatusResponse = makeGetTransactionResponse(
        validated: true,
        resultCode: transactionStatusCodeFailure
      )
      let networkClient = FakeNetworkClient(
        accountInfoResult: .success(.testGetAccountInfoResponse),
        feeResult: .success(.testGetFeeResponse),
        submitTransactionResult: .success(.testSubmitTransactionResponse),
        transactionStatusResult: .success(transactionStatusResponse),
        transactionHistoryResult: .success(.testTransactionHistoryResponse)
      )
      let xrpClient = DefaultXRPClient(networkClient: networkClient)

      // WHEN the transaction status is retrieved.
      let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

      // THEN the transaction status is failed.
      XCTAssertEqual(transactionStatus, .failed)
    }
  }

  func testGetTransactionStatusWithValidatedTransactionAndSuccessCode() {
    // GIVEN an XRPClient which returns a validated transaction and a succeeded transaction status code.
    let transactionStatusResponse = makeGetTransactionResponse(
      validated: true,
      resultCode: .testTransactionStatusCodeSuccess
    )
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(transactionStatusResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the transaction status is retrieved.
    let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

    // THEN the transaction status is succeeded.
    XCTAssertEqual(transactionStatus, .succeeded)
  }

  func testGetTransactionStatusWithServerFailure() {
    // GIVEN an XRPClient which fails to return a transaction status.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .failure(XpringKitTestError.mockFailure),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the transaction status is retrieved THEN an error is thrown.
    XCTAssertThrowsError(try xrpClient.getTransactionStatus(for: .testTransactionHash))
  }

  func testTransactionStatusWithUnsupportedTransactionType() {
    // GIVEN an XRPClient which will return a non-payment type transaction.
    let getTransactionResponse = Org_Xrpl_Rpc_V1_GetTransactionResponse.with {
      $0.transaction = Org_Xrpl_Rpc_V1_Transaction()
    }
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(getTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the transaction status is retrieved.
    let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

    // THEN the status is UNKNOWN.
    XCTAssertEqual(transactionStatus, .unknown)
  }

  func testTransactionStatusWithPartialPayment() {
    // GIVEN an XRPClient which will return a partial payment type transaction.
    let getTransactionResponse = Org_Xrpl_Rpc_V1_GetTransactionResponse.with {
      $0.transaction = Org_Xrpl_Rpc_V1_Transaction.with {
        $0.payment = Org_Xrpl_Rpc_V1_Payment()
        $0.flags = Org_Xrpl_Rpc_V1_Flags.with {
          $0.value = RippledFlags.tfPartialPayment.rawValue
        }
      }
    }
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(getTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the transaction status is retrieved.
    let transactionStatus = try? xrpClient.getTransactionStatus(for: .testTransactionHash)

    // THEN the status is UNKNOWN.
    XCTAssertEqual(transactionStatus, .unknown)
  }

  // MARK: - Account Existence
  func testAccountExistsWithSuccess() {
    // GIVEN an XRPClient which will successfully return a balance from a mocked network call.
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN the existence of the account is checked.
    guard let exists = try? xrpClient.accountExists(for: .testAddress) else {
      XCTFail("Exception should not be thrown when checking existence of valid account")
      return
    }

    // THEN the balance is correct.
    XCTAssertTrue(exists)
  }

  func testAccountExistsWithClassicAddress() {
    // GIVEN a classic address.
    guard let classicAddressComponents = Utils.decode(xAddress: .testAddress) else {
      XCTFail("Failed to decode X-Address.")
      return
    }
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN the account's existence is checked THEN an error is thrown.
    XCTAssertThrowsError(
      try xrpClient.accountExists(for: classicAddressComponents.classicAddress),
      "Exception not thrown"
    ) { error in
      guard
        case .invalidInputs = error as? XRPLedgerError
      else {
        XCTFail("Error thrown was not invalid inputs error")
        return
      }
    }
  }

  func testAccountExistsWithNotFoundFailure() {
    // GIVEN an XRPClient which will throw an RPCError w/ StatusCode notFound when a balance is requested.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .failure(RPCError.callError(CallResult(success: false, statusCode: StatusCode.notFound, statusMessage: "Mocked RPCError w/ notFound StatusCode", resultData: nil, initialMetadata: nil, trailingMetadata: nil))),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the existence of the account is checked
    guard let exists = try? xrpClient.accountExists(for: .testAddress) else {
      XCTFail("Exception should not be thrown when checking existence of non-existent account")
      return
    }

    // THEN false is returned.
    XCTAssertFalse(exists)
  }

  func testAccountExistsWithUnknownFailure() {
    // GIVEN an XRPClient which will throw an RPCError w/ StatusCode unknown when a balance is requested.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .failure(RPCError.callError(CallResult(success: false, statusCode: StatusCode.unknown, statusMessage: "Mocked RPCError w/ unknown StatusCode", resultData: nil, initialMetadata: nil, trailingMetadata: nil))),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .success(.testTransactionHistoryResponse)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the account's existence is checked THEN the error is re-thrown.
    XCTAssertThrowsError(
      try xrpClient.accountExists(for: .testAddress),
      "Exception not thrown"
    ) { error in
      guard
        case .callError = error as? RPCError
      else {
        XCTFail("Error thrown was not RPCError.callError")
        return
      }
    }
  }

  // MARK: - Payment History

// TODO(keefertaylor): Re-enable when XRPClient can return transactions
//  func testTransactionHistoryWithSuccess() {
//    // GIVEN an XRPClient client which will successfully return a transactionHistory mocked network call.
//    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)
//    let expectedTransactions =
//      Org_Xrpl_Rpc_V1_GetAccountTransactionHistoryResponse.testTransactionHistoryResponse.transactions.map { transactionResponse in
//        return XRPTransaction(transaction: transactionResponse.transaction)
//      }
//
//    // WHEN the transactionHistory is requested.
//    guard let transactions = try? xrpClient.getTransactionHistory(for: .testAddress) else {
//      XCTFail("Exception should not be thrown when trying to get a balance")
//      return
//    }
//
//    // THEN the balance is correct.
//    XCTAssertEqual(transactions, expectedTransactions)
//  }

  func testGetPaymentHistoryWithClassicAddress() {
    // GIVEN a classic address.
    guard let classicAddressComponents = Utils.decode(xAddress: .testAddress) else {
      XCTFail("Failed to decode X-Address.")
      return
    }
    let xrpClient = DefaultXRPClient(networkClient: FakeNetworkClient.successfulFakeNetworkClient)

    // WHEN the payment history is requested THEN an error is thrown.
    XCTAssertThrowsError(
      try xrpClient.paymentHistory(for: classicAddressComponents.classicAddress),
      "Exception not thrown"
    ) { error in
      guard
        case .invalidInputs = error as? XRPLedgerError
      else {
        XCTFail("Error thrown was not invalid inputs error")
        return
      }

    }
  }

  func testGetPaymentHistoryWithFailure() {
    // GIVEN an XRPClient client which will throw an error when a balance is requested.
    let networkClient = FakeNetworkClient(
      accountInfoResult: .success(.testGetAccountInfoResponse),
      feeResult: .success(.testGetFeeResponse),
      submitTransactionResult: .success(.testSubmitTransactionResponse),
      transactionStatusResult: .success(.testGetTransactionResponse),
      transactionHistoryResult: .failure(XpringKitTestError.mockFailure)
    )
    let xrpClient = DefaultXRPClient(networkClient: networkClient)

    // WHEN the payment history is requested THEN an error is thrown.
    XCTAssertThrowsError(try xrpClient.paymentHistory(for: .testAddress), "Exception not thrown") { error in
      guard
        let _ = error as? XpringKitTestError
      else {
        XCTFail("Error thrown was not mocked error")
        return
      }
    }
  }

  // MARK: - Helpers
  private func makeGetTransactionResponse(
    validated: Bool,
    resultCode: String
  ) -> Org_Xrpl_Rpc_V1_GetTransactionResponse {
    return Org_Xrpl_Rpc_V1_GetTransactionResponse.with {
      $0.validated = validated
      $0.meta = Org_Xrpl_Rpc_V1_Meta.with {
        $0.transactionResult = Org_Xrpl_Rpc_V1_TransactionResult.with {
          $0.result = resultCode
        }
      }
      $0.transaction = Org_Xrpl_Rpc_V1_Transaction.with {
        $0.payment = Org_Xrpl_Rpc_V1_Payment()
      }
    }
  }
}
