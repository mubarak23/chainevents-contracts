#[starknet::contract]
pub mod PaymentToken {
    use starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapWriteAccess, StorageMapReadAccess,
    };
    use chainevents_contracts::interfaces::IPaymentToken::IERC20;
    use core::num::traits::Zero;

    #[storage]
    pub struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>, // Mapping<(owner, spender), amount>
        token_name: ByteArray,
        symbol: ByteArray,
        decimal: u8,
        total_supply: u256,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.token_name.write("Payment Token");
        self.symbol.write("PMT");
        self.decimal.write(18);
        self.owner.write(get_caller_address());
    }

    #[abi(embed_v0)]
    impl PaymentTokenImpl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();

            let sender_prev_balance = self.balances.read(sender);
            let recipient_prev_balance = self.balances.read(recipient);

            assert(sender_prev_balance >= amount, 'Insufficient amount');

            self.balances.write(sender, sender_prev_balance - amount);
            self.balances.write(recipient, recipient_prev_balance + amount);

            assert(
                self.balances.read(recipient) > recipient_prev_balance,
                'Transaction failed',
            );

            self.emit(Transfer { from: sender, to: recipient, amount });

            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let spender = get_caller_address();

            let spender_allowance = self.allowances.read((sender, spender));
            let sender_balance = self.balances.read(sender);
            let recipient_balance = self.balances.read(recipient);

            assert(amount <= spender_allowance, 'amount exceeds allowance');
            assert(amount <= sender_balance, 'amount exceeds balance');

            self.allowances.write((sender, spender), spender_allowance - amount);
            self.balances.write(sender, sender_balance - amount);
            self.balances.write(recipient, recipient_balance + amount);

            self.emit(Transfer { from: sender, to: recipient, amount });

            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            self.allowances.write((caller, spender), amount);

            self.emit(Approval { owner: caller, spender, value: amount });

            true
        }

        fn name(self: @ContractState) -> ByteArray {
            self.token_name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimal.read()
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let previous_total_supply = self.total_supply.read();
            let previous_balance = self.balances.read(recipient);

            self.total_supply.write(previous_total_supply + amount);
            self.balances.write(recipient, previous_balance + amount);

            let zero_address = Zero::zero();

            self.emit(Transfer { from: zero_address, to: recipient, amount });

            true
        }
    }
}
