use starknet::{ContractAddress, ClassHash};
// *************************************************************************
//                              INTERFACE of TOKEN GIVER NFT
// *************************************************************************
#[starknet::interface]
pub trait ITicketEventNft<TState> {
    fn mint_token_giver_nft(ref self: TState, address: ContractAddress) -> u256;
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
    fn get_last_minted_id(self: @TState) -> u256;
    fn get_user_token_id(self: @TState, user: ContractAddress) -> u256;
    // fn get_token_mint_timestamp(self: @TState, token_id: u256) -> u64;
    // fn get_token_uri(self: @TState, token_id: u256) -> ByteArray;
}
