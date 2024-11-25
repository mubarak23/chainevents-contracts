use starknet::ContractAddress;

#[starknet::interface]
pub trait IEventNFT<TContractState> {
    fn mint_nft(ref self: TContractState, user_address: ContractAddress) -> u256;
    fn burn_nft(ref self: TContractState, user_address: ContractAddress, token_id: u256);
}
