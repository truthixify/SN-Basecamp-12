#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
    fn get_win_number(self: @TContractState) -> u32;
}

#[starknet::contract]
pub mod Counter {
    use OwnableComponent::InternalTrait;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use super::ICounter;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // STRK token address on Starknet
    pub const FELT_STRK_CONTRACT: felt252 =
        0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;

    // Win number - when counter reaches this, caller gets all STRK
    pub const WIN_NUMBER: u32 = 10;

    #[storage]
    pub struct Storage {
        pub counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        // Initialize the counter with the provided value
        self.counter.write(init_value);
        self.ownable.initializer(owner);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increased: Increased,
        Decreased: Decreased,
        Reset: Reset,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increased {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Reset {
        pub account: ContractAddress,
    }

    pub mod Error {
        pub const EMPTY_COUNTER: felt252 = 'Decreasing Empty Counter';
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let new_value = self.counter.read() + 1;
            self.counter.write(new_value);
            self.emit(Increased { account: get_caller_address() });

            // Check if counter reached the win number
            if new_value == WIN_NUMBER {
                let caller = get_caller_address();
                let strk_contract_address: ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

                // Get STRK token dispatcher
                let strk_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

                // Get contract's STRK balance
                let balance = strk_dispatcher.balance_of(get_contract_address());

                if balance > 0 {
                    // Transfer all STRK from contract to caller
                    strk_dispatcher.transfer(caller, balance);
                }
            }
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased { account: get_caller_address() });
        }

        fn reset_counter(ref self: ContractState) {
            let caller = get_caller_address();
            let strk_contract_address: ContractAddress = FELT_STRK_CONTRACT.try_into().unwrap();

            // Get STRK token dispatcher
            let strk_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

            // Get contract's current STRK balance
            let contract_balance = strk_dispatcher.balance_of(get_contract_address());

            // Transfer all STRK from contract to caller
            if contract_balance > 0 {
                strk_dispatcher.transfer_from(caller, get_contract_address(), contract_balance);
            }

            // only owner can reset the counter
            self.ownable.assert_only_owner();
            self.counter.write(0);
            self.emit(Reset { account: get_caller_address() });
        }

        fn get_win_number(self: @ContractState) -> u32 {
            WIN_NUMBER
        }
    }
}
