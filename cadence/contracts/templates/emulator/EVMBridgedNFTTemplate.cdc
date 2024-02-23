import NonFungibleToken from 0xf8d6e0586b0a20c7
import MetadataViews from 0xf8d6e0586b0a20c7
import ViewResolver from 0xf8d6e0586b0a20c7
import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

import EVM from 0xf8d6e0586b0a20c7

import ICrossVM from 0xf8d6e0586b0a20c7
import IEVMBridgeNFTMinter from 0xf8d6e0586b0a20c7
import FlowEVMBridgeNFTEscrow from 0xf8d6e0586b0a20c7
import FlowEVMBridgeConfig from 0xf8d6e0586b0a20c7
import FlowEVMBridgeUtils from 0xf8d6e0586b0a20c7
import FlowEVMBridge from 0xf8d6e0586b0a20c7
import CrossVMNFT from 0xf8d6e0586b0a20c7

/// This contract is a template used by FlowEVMBridge to define EVM-native NFTs bridged from Flow EVM to Flow.
/// Upon deployment of this contract, the contract name is derived as a function of the asset type (here an ERC721 aka
/// an NFT) and the contract's EVM address. The derived contract name is then joined with this contract's code, 
/// prepared as chunks in FlowEVMBridgeTemplates before being deployed to the Flow EVM Bridge account.
///
/// On bridging, the ERC721 is transferred to the bridge's CadenceOwnedAccount EVM address and a new NFT is minted from
/// this contract to the bridging caller. On return to Flow EVM, the reverse process is followed - the token is burned
/// in this contract and the ERC721 is transferred to the defined recipient. In this way, the Cadence token acts as a
/// representation of both the EVM NFT and thus ownership rights to it upon bridging back to Flow EVM.
///
/// To bridge between VMs, a caller can either use the contract methods defined below, or use the FlowEVMBridge's
/// bridging methods which will programatically route bridging calls to this contract.
///
// TODO: Implement NFT contract interface once v2 available locally
access(all) contract CONTRACT_NAME : ICrossVM, IEVMBridgeNFTMinter, ViewResolver {

    /// Pointer to the Factory deployed Solidity contract address defining the bridged asset
    access(all) let evmNFTContractAddress: EVM.EVMAddress
    /// Pointer to the Flow NFT contract address defining the bridged asset, this contract address in this case
    access(all) let flowNFTContractAddress: Address
    /// Name of the NFT collection defined in the corresponding ERC721 contract
    access(all) let name: String
    /// Symbol of the NFT collection defined in the corresponding ERC721 contract
    access(all) let symbol: String
    /// Retain a Collection to reference when resolving Collection Metadata
    access(self) let collection: @Collection

    /// We choose the name NFT here, but this type can have any name now
    /// because the interface does not require it to have a specific name any more
    access(all) resource NFT: CrossVMNFT.EVMNFT {

        access(all) let id: UInt64
        access(all) let evmID: UInt256
        access(all) let name: String
        access(all) let symbol: String

        access(all) let uri: String
        access(all) let metadata: {String: AnyStruct}

        init(
            name: String,
            symbol: String,
            evmID: UInt256,
            uri: String,
            metadata: {String: AnyStruct}
        ) {
            self.name = name
            self.symbol = symbol
            self.id = self.uuid
            self.evmID = evmID
            self.uri = uri
            self.metadata = metadata
        }

        /// Returns the id of the NFT
        access(all) view fun getID(): UInt64 {
            return self.id
        }

        /// Returns the metadata view types supported by this NFT
        access(all) view fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        /// Resolves a metadata view for this NFT
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                // We don't know what kind of file the URI represents (IPFS v HTTP), so we can't resolve Display view
                // with the URI as thumbnail - we may a new standard view for EVM NFTs - this is interim
                case Type<CrossVMNFT.BridgedMetadata>():
                    return CrossVMNFT.BridgedMetadata(
                        name: self.name,
                        symbol: self.symbol,
                        uri: CrossVMNFT.URI(self.uri),
                        evmContractAddress: self.getEVMContractAddress()
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return CONTRACT_NAME.getCollectionData(nftType: Type<@CONTRACT_NAME.NFT>())
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return CONTRACT_NAME.getCollectionDisplay(nftType: Type<@CONTRACT_NAME.NFT>())
            }
            return nil
        }

        /// public function that anyone can call to create a new empty collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection} {
            return <- create CONTRACT_NAME.Collection()
        }

        /* --- CrossVMNFT conformance --- */
        //
        /// Returns the EVM contract address of the NFT
        access(all) fun getEVMContractAddress(): EVM.EVMAddress {
            return CONTRACT_NAME.getEVMContractAddress()
        }

        /// Similar to ERC721.tokenURI method, returns the URI of the NFT with self.evmID at time of bridging
        access(all) fun tokenURI(): String {
            return self.uri
        }
    }

    access(all) resource Collection: NonFungibleToken.Collection, CrossVMNFT.EVMNFTCollection {
        /// dictionary of NFT conforming tokens indexed on their ID
        access(contract) var ownedNFTs: @{UInt64: CONTRACT_NAME.NFT}
        /// Mapping of EVM IDs to Flow NFT IDs
        access(contract) let evmIDToFlowID: {UInt256: UInt64}

        access(self) var storagePath: StoragePath
        access(self) var publicPath: PublicPath

        /// Return the default storage path for the collection
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return self.storagePath
        }

        /// Return the default public path for the collection
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return self.publicPath
        }

        init () {
            self.ownedNFTs <- {}
            self.evmIDToFlowID = {}
            let identifier = "CONTRACT_NAMECollection"
            self.storagePath = StoragePath(identifier: identifier)!
            self.publicPath = PublicPath(identifier: identifier)!
        }

        /// Returns a list of NFT types that this receiver accepts
        access(all) view fun getSupportedNFTTypes(): {Type: Bool} {
            return { Type<@CONTRACT_NAME.NFT>(): true }
        }

        /// Returns whether or not the given type is accepted by the collection
        /// A collection that can accept any type should just return true by default
        access(all) view fun isSupportedNFTType(type: Type): Bool {
           return type == Type<@CONTRACT_NAME.NFT>()
        }

        /// Removes an NFT from the collection and moves it to the caller
        access(NonFungibleToken.Withdrawable) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        /// Withdraws an NFT from the collection by its EVM ID
        access(NonFungibleToken.Withdrawable) fun withdrawByEVMID(_ id: UInt64): @{NonFungibleToken.NFT} {
            let token <- self.ownedNFTs.remove(key: id)
                ?? panic("Could not withdraw an NFT with the provided ID from the collection")

            return <-token
        }

        /// Ttakes a NFT and adds it to the collections dictionary and adds the ID to the evmIDToFlowID mapping
        access(all) fun deposit(token: @{NonFungibleToken.NFT}) {
            let token <- token as! @CONTRACT_NAME.NFT

            // add the new token to the dictionary which removes the old one
            self.evmIDToFlowID[token.evmID] = token.id
            let oldToken <- self.ownedNFTs[token.id] <- token

            destroy oldToken
        }

        /// Returns an array of the IDs that are in the collection
        access(all) view fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Returns an array of the EVM IDs that are in the collection
        access(all) view fun getEVMIDs(): [UInt256] {
            return self.evmIDToFlowID.keys
        }

        /// Returns the Cadence NFT.id for the given EVM NFT ID if 
        access(all) view fun getCadenceID(from evmID: UInt256): UInt64? {
            return self.evmIDToFlowID[evmID] ?? UInt64(evmID)
        }

        /// Gets the amount of NFTs stored in the collection
        access(all) view fun getLength(): Int {
            return self.ownedNFTs.keys.length
        }

        /// Retrieves a reference to the NFT stored in the collection by its ID
        access(all) view fun borrowNFT(_ id: UInt64): &{NonFungibleToken.NFT}? {
            return &self.ownedNFTs[id]
        }

        /// Borrow the view resolver for the specified NFT ID
        access(all) view fun borrowViewResolver(id: UInt64): &{ViewResolver.Resolver}? {
            if let nft = &self.ownedNFTs[id] as &CONTRACT_NAME.NFT? {
                return nft as &{ViewResolver.Resolver}
            }
            return nil
        }

        /// Creates an empty collection
        access(all) fun createEmptyCollection(): @{NonFungibleToken.Collection}  {
            return <- create Collection()
        }
    }

    /// public function that anyone can call to create a new empty collection
    /// Since multiple collection types can be defined in a contract,
    /// The caller needs to specify which one they want to create
    access(all) fun createEmptyCollection(): @CONTRACT_NAME.Collection {
        return <- create Collection()
    }

    /**********************
            Getters
    ***********************/

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all) view fun getViews(): [Type] {
        return [
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all) fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.NFTCollectionData>():
                return CONTRACT_NAME.getCollectionData(nftType: Type<@CONTRACT_NAME.NFT>())
            case Type<MetadataViews.NFTCollectionDisplay>():
                return CONTRACT_NAME.getCollectionDisplay(nftType: Type<@CONTRACT_NAME.NFT>())
        }
        return nil
    }

    /// resolve a type to its CollectionData so you know where to store it
    /// Returns `nil` if no collection type exists for the specified NFT type
    access(all) view fun getCollectionData(nftType: Type): MetadataViews.NFTCollectionData? {
        switch nftType {
            case Type<@CONTRACT_NAME.NFT>():
                let collectionRef: &Collection = &self.collection
                let collectionData = MetadataViews.NFTCollectionData(
                    storagePath: collectionRef.getDefaultStoragePath()!,
                    publicPath: collectionRef.getDefaultPublicPath()!,
                    providerPath: /private/CONTRACT_NAMECollection,
                    publicCollection: Type<&CONTRACT_NAME.Collection>(),
                    publicLinkedType: Type<&CONTRACT_NAME.Collection>(),
                    providerLinkedType: Type<auth(NonFungibleToken.Withdrawable) &CONTRACT_NAME.Collection>(),
                    createEmptyCollectionFunction: (fun(): @{NonFungibleToken.Collection} {
                        return <-CONTRACT_NAME.createEmptyCollection()
                    })
                )
                return collectionData
            default:
                return nil
        }
    }

    /// Returns the CollectionDisplay view for the NFT type that is specified
    // TODO: Replace with generalized bridge collection display
    access(all) view fun getCollectionDisplay(nftType: Type): MetadataViews.NFTCollectionDisplay? {
        switch nftType {
            case Type<@CONTRACT_NAME.NFT>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The FlowVM Bridged NFT Collection",
                    description: "This collection was bridged from Flow EVM.",
                    externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                    squareImage: media,
                    bannerImage: media,
                    socials: {}
                )
            default:
                return nil
        }
    }

    /// Returns the EVM contract address of the NFT this contract represents
    ///
    access(all) fun getEVMContractAddress(): EVM.EVMAddress {
        return self.evmNFTContractAddress
    }

    access(account)
    fun mintNFT(id: UInt256, tokenURI: String): @NFT {
        return <-create NFT(
            name: self.name,
            symbol: self.symbol,
            evmID: id,
            uri: tokenURI,
            metadata: {
                "Bridged Block": getCurrentBlock().height,
                "Bridged Timestamp": getCurrentBlock().timestamp
            }
        )
    }

    // TODO: Revisit once NFT v2 standards are available locally
    access(self) fun burnNFT(nft: @CONTRACT_NAME.NFT) {
        destroy nft
    }

    init(name: String, symbol: String, evmContractAddress: EVM.EVMAddress) {
        self.evmNFTContractAddress = evmContractAddress
        self.flowNFTContractAddress = self.account.address
        self.name = name
        self.symbol = symbol
        self.collection <- create Collection()

        FlowEVMBridgeConfig.associateType(Type<@CONTRACT_NAME.NFT>(), with: self.evmNFTContractAddress)
        FlowEVMBridgeNFTEscrow.initializeEscrow(
            forType: Type<@CONTRACT_NAME.NFT>(),
            erc721Address: self.evmNFTContractAddress
        )
    }
}
