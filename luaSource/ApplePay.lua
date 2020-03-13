local luapatch = require("luapatch")
luapatch.redefineInstanceMethod("ApplePay","init","ApplePay_init","id")
--luapatch.addInstanceMethod("ApplePay","init","ApplePay_init","void")
function ApplePay_init(instance)
    -- body
    instance.super().init()
    luapatch.packClass("SKPaymentQueue").defaultQueue().addTransactionObserver(instance)
    return instance
end

luapatch.addInstanceMethod("ApplePay","pay:","ApplePay_openpay","void_id")
function ApplePay_openpay(instance,productIdentifier)
    -- body
    local SKMutablePayment = luapatch.packClass("SKMutablePayment")
    local mutablePayment = SKMutablePayment.alloc().init()
    mutablePayment.setProductIdentifier(productIdentifier)
    mutablePayment.setQuantity(1)
    luapatch.packClass("SKPaymentQueue").defaultQueue().addPayment(mutablePayment)
end

luapatch.redefineInstanceMethod("ApplePay","paymentQueue:updatedTransactions:","ApplePay_paymentQueue_updatedTransactions","void_id_id")
function ApplePay_paymentQueue_updatedTransactions(instance,queue,transactions)
    -- body
    print("call ApplePay_paymentQueue_updatedTransactions")
    local count = transactions.count()
    print("count is ")
    print(count)
    local transaction = {}
    for i = 0, count-1 do
        transaction = transactions.objectAtIndex(i)
        if transaction.transactionState() == 1 then --SKPaymentTransactionStatePurchased
            print("transaction is SKPaymentTransactionStatePurchased in lua")
            luapatch.packClass("SKPaymentQueue").defaultQueue().finishTransaction(transaction)
        elseif transaction.transactionState() == 2 then --SKPaymentTransactionStateFailed
            print("transaction is SKPaymentTransactionStateFailed in lua")
            luapatch.packClass("SKPaymentQueue").defaultQueue().finishTransaction(transaction)
        else
            print("transaction is default in lua")
        end
    end
end
