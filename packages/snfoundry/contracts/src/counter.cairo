#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod Counter {
    use OwnableComponent::InternalTrait;
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use super::ICounter;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;


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
        Increaesed: Increase,
        Decreased: Decrease,
        Reset: Reset,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increase {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decrease {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Reset {
        pub account: ContractAddress,
    }

    pub mod Error {
        pub const EMPTY_COUNTER: felt252 = 'Decreasing Empty Counter';
        pub const UNDERFLOW: felt252 = 'Decreasing Counter Underflow';
        pub const OVERFLOW: felt252 = 'Increasing Counter Overflow';
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let new_value = self.counter.read() + 1;
            // assert(new_value < 2u32.pow(32), Error::OVERFLOW);
            self.counter.write(new_value);
            self.emit(Increase { account: get_caller_address() });
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            // assert(old_value > 1, Error::UNDERFLOW);
            self.counter.write(old_value - 1);
            self.emit(Decrease { account: get_caller_address() });
        }

        fn reset_counter(ref self: ContractState) {
            // only owner can reset the counter
            self.ownable.assert_only_owner();
            self.counter.write(0);
            self.emit(Reset { account: get_caller_address() });
        }
    }
}
