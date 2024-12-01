use starknet::ContractAddress;

#[starknet::interface]
pub trait IEventNFT<TContractState> {
    fn mint_nft(ref self: TContractState, user_address: ContractAddress) -> u256;
    fn burn_nft(ref self: TContractState, user_address: ContractAddress, token_id: u256);
    fn get_user_token_id(self: @TContractState, user_address: ContractAddress) -> u256;
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn token_uri(self: @TContractState, token_id: u256) -> ByteArray;
}
