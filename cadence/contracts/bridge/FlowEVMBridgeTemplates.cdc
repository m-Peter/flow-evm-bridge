import "FungibleToken"
import "NonFungibleToken"

import "FlowEVMBridgeUtils"

/// This contract serves Cadence code from chunked templates, replacing the contract name with the name derived from
/// given arguments - either Cadence Type or EVM contract address.
///
access(all) contract FlowEVMBridgeTemplates {
    /// Canonical path for the Admin resource
    access(all) let AdminStoragePath: StoragePath
    /// Chunked Hex-encoded Cadence contract code, to be joined on derived contract name
    access(self) let templateCodeChunks: {String: [String]}

    /// Serves Locker contract code for a given type, deriving the contract name from the type identifier
    access(all) fun getLockerContractCode(forType: Type): [UInt8]? {
        if forType.isSubtype(of: Type<@{NonFungibleToken.NFT}>()) && !forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            return self.getNFTLockerContractCode(forType: forType)
        } else if !forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) && forType.isSubtype(of: Type<@{FungibleToken.Vault}>()) {
            // TODO
            return nil
        }
        return nil
    }

    /// Serves bridged asset contract code for a given type, deriving the contract name from the EVM contract info
    // TODO: Consider adding the values we would need to derive from instead of abstracting EVM calls in scope
    // access(all) fun getBridgedAssetContractCode(forEVMContract: EVM.EVMAddress): [UInt8]? {}

    access(self) fun getNFTLockerContractCode(forType: Type): [UInt8]? {
        if let contractName: String = FlowEVMBridgeUtils.deriveLockerContractName(fromType: forType) {
            let contraNameHex: String = String.encodeHex(contractName.utf8)

            // Construct the contract code from the templated chunked contract hex
            let code: [UInt8] = []
            let chunks: [String] = self.templateCodeChunks["nftLocker"]!
            for i, chunk in chunks {
                code.appendAll(chunk.decodeHex())
                // No need to append the contract name after the last chunk
                if i == chunks.length - 1 {
                    break
                }
                code.appendAll(contraNameHex.decodeHex())
            }
            return code
        }

        return nil
    }

    /// Resource enabling updates to the contract template code
    access(all) resource Admin {
        access(all) fun upsertContractCodeChunks(forTemplate: String, chunks: [String]) {
            FlowEVMBridgeTemplates.templateCodeChunks[forTemplate] = chunks
        }
        access(all) fun addNewContractCodeChunks(newTemplate: String, chunks: [String]) {
            pre {
                FlowEVMBridgeTemplates.templateCodeChunks[newTemplate] == nil: "Code already exists for template"
            }
            FlowEVMBridgeTemplates.templateCodeChunks[newTemplate] = chunks
        }
    }


    // Flow CLI currently breaks flow.json on [String] in contract init - hard coding for the time being but needs new
    // hex on template changes
    // init(templateCodeChunks: {String: [String]}) {
    init() {
        self.AdminStoragePath = StoragePath(
                identifier: "flowEVMBridgeTemplatesAdmin_".concat(self.account.address.toString())
            )!
        self.templateCodeChunks = {}
        self.templateCodeChunks["nftLocker"] = [
            "696d706f7274204e6f6e46756e6769626c65546f6b656e2066726f6d203078663864366530353836623061323063370a696d706f7274204d6574616461746156696577732066726f6d203078663864366530353836623061323063370a696d706f727420566965775265736f6c7665722066726f6d203078663864366530353836623061323063370a696d706f727420466c6f77546f6b656e2066726f6d203078306165353363623665336634326137390a0a696d706f72742045564d2066726f6d203078663864366530353836623061323063370a0a696d706f7274204945564d4272696467654e46544c6f636b65722066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d427269646765436f6e6669672066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d4272696467655574696c732066726f6d203078663864366530353836623061323063370a696d706f727420466c6f7745564d4272696467652066726f6d203078663864366530353836623061323063370a0a2f2f20544f444f3a0a2f2f202d205b205d20436f6e73696465722063617365207768657265204e46542049447320617265206e6f7420756e69717565202d206973207468697320776f72746820737570706f7274696e673f0a2f2f202d205b205d2050756c6c205552492066726f6d204e465420696620646973706c61792065786973747320262070617373206f6e206d696e74696e670a2f2f0a61636365737328616c6c2920636f6e747261637420",
            "203a204945564d4272696467654e46544c6f636b6572207b0a202020202f2f2f2054797065206f66204e4654206c6f636b656420696e2074686520636f6e74726163740a2020202061636365737328616c6c29206c6574206c6f636b65644e4654547970653a20547970650a202020202f2f2f20506f696e74657220746f2074686520646566696e696e6720466c6f772d6e617469766520636f6e74726163740a2020202061636365737328616c6c29206c657420666c6f774e4654436f6e7472616374416464726573733a20416464726573730a202020202f2f2f20506f696e74657220746f2074686520466163746f7279206465706c6f79656420536f6c696469747920636f6e7472616374206164647265737320646566696e696e672074686520627269646765642061737365740a2020202061636365737328616c6c29206c65742065766d4e4654436f6e7472616374416464726573733a2045564d2e45564d416464726573730a202020202f2f2f205265736f7572636520776869636820686f6c6473206c6f636b6564204e4654730a2020202061636365737328636f6e747261637429206c6574206c6f636b65723a20407b4945564d4272696467654e46544c6f636b65722e4c6f636b65727d0a0a202020202f2a202d2d2d20417578696c6961727920656e747279706f696e7473202d2d2d202a2f0a0a202020202f2f20544f444f3a20436f6e736964657220696d706c656d656e74696e67204943726f737345564d4e46542e45564d42726964676561626c65436f6c6c656374696f6e20696e204c6f636b657220616e642070617373696e67207468726f75676820746f204c6f636b65720a202020202f2f202020202020617320616e206578616d706c65206f6620612062726964676561626c6520636f6c6c656374696f6e0a2020202061636365737328616c6c292066756e20627269646765546f45564d28746f6b656e3a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d2c20746f3a2045564d2e45564d416464726573732c20746f6c6c4665653a2040466c6f77546f6b656e2e5661756c7429207b0a2020202020202020707265207b0a202020202020202020202020746f6b656e2e676574547970652829203d3d2073656c662e6c6f636b65644e4654547970653a2022496e76616c6964204e4654207479706520666f722074686973204c6f636b6572220a202020202020202020202020746f6c6c4665652e67657442616c616e63652829203e3d20466c6f7745564d427269646765436f6e6669672e6665653a2022496e73756666696369656e74206272696467696e67206665652070726f7669646564220a20202020202020207d0a2020202020202020466c6f7745564d4272696467655574696c732e6465706f736974546f6c6c466565283c2d746f6c6c466565290a20202020202020206c65742069643a2055496e74323536203d2055496e7432353628746f6b656e2e67657449442829290a0a20202020202020206c6574206973466c6f774e6174697665203d20466c6f7745564d4272696467655574696c732e6973466c6f774e617469766528747970653a20746f6b656e2e676574547970652829290a0a202020202020202073656c662e6c6f636b65722e6465706f73697428746f6b656e3a203c2d746f6b656e290a20202020202020202f2f20544f444f202d2070756c6c205552492066726f6d204e465420696620646973706c61792065786973747320262070617373206f6e206d696e74696e670a2020202020202020466c6f7745564d4272696467655574696c732e63616c6c280a2020202020202020202020207369676e61747572653a2022736166654d696e7428616464726573732c75696e743235362c737472696e6729222c0a20202020202020202020202074617267657445564d416464726573733a2073656c662e65766d4e4654436f6e7472616374416464726573732c0a202020202020202020202020617267733a205b746f2c2069642c20224d4f434b5f555249225d2c0a2020202020202020202020206761734c696d69743a2031353030303030302c0a20202020202020202020202076616c75653a20302e300a2020202020202020290a202020207d0a0a2020202061636365737328616c6c292066756e2062726964676546726f6d45564d280a202020202020202063616c6c65723a202645564d2e427269646765644163636f756e742c0a202020202020202063616c6c646174613a205b55496e74385d2c0a202020202020202069643a2055496e743235362c0a202020202020202065766d436f6e7472616374416464726573733a2045564d2e45564d416464726573732c0a2020202020202020746f6c6c4665653a2040466c6f77546f6b656e2e5661756c740a20202020293a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d207b0a2020202020202020707265207b0a202020202020202020202020746f6c6c4665652e67657442616c616e63652829203e3d20466c6f7745564d427269646765436f6e6669672e6665653a2022496e73756666696369656e74206272696467696e67206665652070726f7669646564220a20202020202020202020202065766d436f6e7472616374416464726573732e6279746573203d3d2073656c662e65766d4e4654436f6e7472616374416464726573732e62797465733a202245564d20636f6e74726163742061646472657373206973206e6f74206173736f63696174656420776974682074686973204c6f636b6572220a20202020202020207d0a20202020202020206c65742069734e46543a20426f6f6c203d20466c6f7745564d4272696467655574696c732e697345564d4e46542865766d436f6e7472616374416464726573733a2065766d436f6e747261637441646472657373290a20202020202020206c6574206973546f6b656e3a20426f6f6c203d20466c6f7745564d4272696467655574696c732e697345564d546f6b656e2865766d436f6e7472616374416464726573733a2065766d436f6e747261637441646472657373290a20202020202020206173736572742869734e465420262620216973546f6b656e2c206d6573736167653a2022556e737570706f72746564206173736574207479706522290a0a20202020202020202f2f20456e737572652063616c6c65722069732063757272656e74204e4654206f776e6572206f7220617070726f7665640a20202020202020206c6574206973417574686f72697a65643a20426f6f6c203d20466c6f7745564d4272696467655574696c732e69734f776e65724f72417070726f766564280a2020202020202020202020206f664e46543a2069642c0a2020202020202020202020206f776e65723a2063616c6c65722e6164647265737328292c0a20202020202020202020202065766d436f6e7472616374416464726573733a2065766d436f6e7472616374416464726573730a2020202020202020290a2020202020202020617373657274286973417574686f72697a65642c206d6573736167653a202243616c6c6572206973206e6f7420746865206f776e6572206f66206f7220617070726f76656420666f7220726571756573746564204e465422290a0a20202020202020202f2f204465706f736974206665650a2020202020202020466c6f7745564d4272696467655574696c732e6465706f736974546f6c6c466565283c2d746f6c6c466565290a0a20202020202020202f2f20457865637574652070726f766964656420617070726f76652063616c6c0a202020202020202063616c6c65722e63616c6c280a202020202020202020202020746f3a2065766d436f6e7472616374416464726573732c0a202020202020202020202020646174613a2063616c6c646174612c0a2020202020202020202020206761734c696d69743a2031353030303030302c0a20202020202020202020202076616c75653a2045564d2e42616c616e636528666c6f773a20302e30290a2020202020202020290a0a20202020202020202f2f2045786563757465207472616e73666572206f66204e465420746f2062726964676520434f4120616464726573730a2020202020202020466c6f7745564d4272696467655574696c732e63616c6c280a2020202020202020202020207369676e61747572653a20226275726e2875696e7432353629222c0a20202020202020202020202074617267657445564d416464726573733a2065766d436f6e7472616374416464726573732c0a202020202020202020202020617267733a205b69645d2c0a2020202020202020202020206761734c696d69743a2031353030303030302c0a20202020202020202020202076616c75653a20302e300a2020202020202020290a0a20202020202020206c657420726573706f6e73653a205b55496e74385d203d20466c6f7745564d4272696467655574696c732e626f72726f77434f4128292e63616c6c280a20202020202020202020202020202020746f3a2065766d436f6e7472616374416464726573732c0a20202020202020202020202020202020646174613a20466c6f7745564d4272696467655574696c732e656e636f6465414249576974685369676e617475726528226578697374732875696e7432353629222c205b69645d292c0a202020202020202020202020202020206761734c696d69743a2031353030303030302c0a2020202020202020202020202020202076616c75653a2045564d2e42616c616e636528666c6f773a20302e30290a202020202020202020202020290a20202020202020206c6574206465636f6465643a205b416e795374727563745d203d2045564d2e6465636f64654142492874797065733a5b547970653c426f6f6c3e28295d2c20646174613a20726573706f6e7365290a20202020202020206c6574206578697374733a20426f6f6c203d206465636f6465645b305d2061732120426f6f6c0a202020202020202061737365727428657869737473203d3d2066616c73652c206d6573736167653a20224e465420776173206e6f74207375636365737366756c6c79206275726e656422290a0a20202020202020206c657420636f6e76657274656449443a2055496e743634203d20466c6f7745564d4272696467655574696c732e75696e74323536546f55496e7436342876616c75653a206964290a202020202020202072657475726e203c2d2073656c662e6c6f636b65722e776974686472617728776974686472617749443a20636f6e7665727465644944290a202020207d0a0a202020202f2a202d2d2d2047657474657273202d2d2d202a2f0a0a2020202061636365737328616c6c2920766965772066756e206765744c6f636b65644e4654436f756e7428293a20496e74207b0a202020202020202072657475726e2073656c662e6c6f636b65722e6765744c656e67746828290a202020207d0a2020202061636365737328616c6c2920766965772066756e20626f72726f774c6f636b65644e46542869643a2055496e743634293a20267b4e6f6e46756e6769626c65546f6b656e2e4e46547d3f207b0a202020202020202072657475726e2073656c662e6c6f636b65722e626f72726f774e4654286964290a202020207d0a0a202020202f2f2f205265747269657665732074686520636f72726573706f6e64696e672045564d20636f6e747261637420616464726573732c20617373756d696e67206120313a312072656c6174696f6e73686970206265747765656e20564d20696d706c656d656e746174696f6e730a2020202061636365737328616c6c292066756e2067657445564d436f6e74726163744164647265737328293a2045564d2e45564d41646472657373207b0a202020202020202072657475726e2073656c662e65766d4e4654436f6e7472616374416464726573730a202020207d0a0a202020202f2a202d2d2d204c6f636b6572202d2d2d202a2f0a0a202020202f2f20544f444f3a20436f6e736964657220696d706c656d656e74696e67204943726f737345564d4e46542e45564d42726964676561626c65436f6c6c656374696f6e20696e746572666163650a2020202061636365737328616c6c29207265736f75726365204c6f636b6572203a204945564d4272696467654e46544c6f636b65722e4c6f636b6572207b0a20202020202020202f2f2f20436f756e74206f66206c6f636b6564204e465473206173206c6f636b65644e4654732e6c656e677468206d61792065786365656420636f6d7075746174696f6e206c696d6974730a20202020202020206163636573732873656c662920766172206c6f636b65644e4654436f756e743a20496e740a20202020202020202f2f2f20496e6465786564206f6e204e4654205555494420746f2070726576656e7420636f6c6c6973696f6e730a20202020202020206163636573732873656c6629206c6574206c6f636b65644e4654733a20407b55496e7436343a207b4e6f6e46756e6769626c65546f6b656e2e4e46547d7d0a0a2020202020202020696e69742829207b0a20202020202020202020202073656c662e6c6f636b65644e4654436f756e74203d20300a20202020202020202020202073656c662e6c6f636b65644e465473203c2d207b7d0a20202020202020207d0a0a20202020202020202f2a202d2d2d2047657474657273202d2d2d202a2f0a0a20202020202020202f2f2f2052657475726e7320746865206e756d626572206f66206c6f636b6564204e4654730a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e206765744c656e67746828293a20496e74207b0a20202020202020202020202072657475726e2073656c662e6c6f636b65644e4654436f756e740a20202020202020207d0a0a20202020202020202f2f2f2052657475726e732061207265666572656e636520746f20746865204e4654206966206974206973206c6f636b65640a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e20626f72726f774e4654285f2069643a2055496e743634293a20267b4e6f6e46756e6769626c65546f6b656e2e4e46547d3f207b0a20202020202020202020202072657475726e202673656c662e6c6f636b65644e4654735b69645d0a20202020202020207d0a0a20202020202020202f2f2f2052657475726e732061206d6170206f6620737570706f72746564204e4654207479706573202d20617420746865206d6f6d656e74204c6f636b657273206f6e6c7920737570706f727420746865206c6f636b65644e46545479706520646566696e65642062790a20202020202020202f2f2f20746865697220636f6e74726163740a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e20676574537570706f727465644e4654547970657328293a207b547970653a20426f6f6c7d207b0a20202020202020202020202072657475726e207b0a20202020202020202020202020202020",
            "2e6c6f636b65644e4654547970653a2073656c662e6973537570706f727465644e46545479706528747970653a20",
            "2e6c6f636b65644e465454797065290a2020202020202020202020207d0a20202020202020207d0a0a20202020202020202f2f2f2052657475726e73207472756520696620746865204e4654207479706520697320737570706f727465640a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e206973537570706f727465644e46545479706528747970653a2054797065293a20426f6f6c207b0a20202020202020202020202072657475726e2074797065203d3d20",
            "2e6c6f636b65644e4654547970650a20202020202020207d0a0a20202020202020202f2f2f2052657475726e73207472756520696620746865204e4654206973206c6f636b65640a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e2069734c6f636b65642869643a2055496e743634293a20426f6f6c207b0a20202020202020202020202072657475726e2073656c662e626f72726f774e46542869642920213d206e696c0a20202020202020207d0a0a20202020202020202f2f2f2052657475726e7320746865204e46542061732061205265736f6c766572206966206974206973206c6f636b65640a202020202020202061636365737328616c6c2920766965772066756e20626f72726f77566965775265736f6c7665722869643a2055496e743634293a20267b566965775265736f6c7665722e5265736f6c7665727d3f207b0a20202020202020202020202072657475726e2073656c662e626f72726f774e4654286964290a20202020202020207d0a0a20202020202020202f2f2f20446570656e64696e67206f6e20746865206e756d626572206f66206c6f636b6564204e4654732c2074686973206d6179206661696c2e205365652069734c6f636b656428292061732066616c6c6261636b20746f20636865636b2069662061732073706563696669630a20202020202020202f2f2f204e4654206973206c6f636b65640a20202020202020202f2f2f0a202020202020202061636365737328616c6c2920766965772066756e2067657449447328293a205b55496e7436345d207b0a20202020202020202020202072657475726e2073656c662e6c6f636b65644e4654732e6b6579730a20202020202020207d0a0a20202020202020202f2f2f204e6f2064656661756c742073746f72616765207061746820666f722074686973204c6f636b6572206173206974277320636f6e74726163742d6f776e6564202d206e656564656420666f7220436f6c6c656374696f6e20636f6e666f726d616e63650a202020202020202061636365737328616c6c2920766965772066756e2067657444656661756c7453746f726167655061746828293a2053746f72616765506174683f207b0a20202020202020202020202072657475726e206e696c0a20202020202020207d0a0a20202020202020202f2f2f204e6f2064656661756c74207075626c6963207061746820666f722074686973204c6f636b6572206173206974277320636f6e74726163742d6f776e6564202d206e656564656420666f7220436f6c6c656374696f6e20636f6e666f726d616e63650a202020202020202061636365737328616c6c2920766965772066756e2067657444656661756c745075626c69635061746828293a205075626c6963506174683f207b0a20202020202020202020202072657475726e206e696c0a20202020202020207d0a0a20202020202020202f2f2f204465706f7369747320746865204e465420696e746f2074686973206c6f636b65720a202020202020202061636365737328616c6c292066756e206465706f73697428746f6b656e3a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d29207b0a202020202020202020202020707265207b0a2020202020202020202020202020202073656c662e626f72726f774e465428746f6b656e2e6765744944282929203d3d206e696c3a20224e46542077697468207468697320494420616c72656164792065786973747320696e20746865204c6f636b6572220a2020202020202020202020207d0a20202020202020202020202073656c662e6c6f636b65644e4654436f756e74203d2073656c662e6c6f636b65644e4654436f756e74202b20310a20202020202020202020202073656c662e6c6f636b65644e4654735b746f6b656e2e676574494428295d203c2d2120746f6b656e0a20202020202020207d0a0a20202020202020202f2f2f20637265617465456d707479436f6c6c656374696f6e206372656174657320616e20656d70747920436f6c6c656374696f6e0a20202020202020202f2f2f20616e642072657475726e7320697420746f207468652063616c6c657220736f207468617420746865792063616e206f776e204e4654730a20202020202020202f2f20544f444f3a2052656d6f7665206f6e20763220757064617465730a202020202020202061636365737328616c6c292066756e20637265617465456d707479436f6c6c656374696f6e28293a20407b4e6f6e46756e6769626c65546f6b656e2e436f6c6c656374696f6e7d207b0a20202020202020202020202072657475726e203c2d20637265617465204c6f636b657228290a20202020202020207d0a0a20202020202020202f2f2f2057697468647261777320746865204e46542066726f6d2074686973206c6f636b65720a2020202020202020616363657373284e6f6e46756e6769626c65546f6b656e2e576974686472617761626c65292066756e20776974686472617728776974686472617749443a2055496e743634293a20407b4e6f6e46756e6769626c65546f6b656e2e4e46547d207b0a2020202020202020202020202f2f2053686f756c64206e6f742068617070656e2c206275742070726576656e7420756e646572666c6f770a2020202020202020202020206173736572742873656c662e6c6f636b65644e4654436f756e74203e20302c206d6573736167653a20224e6f204e46547320746f20776974686472617722290a20202020202020202020202073656c662e6c6f636b65644e4654436f756e74203d2073656c662e6c6f636b65644e4654436f756e74202d20310a0a20202020202020202020202072657475726e203c2d73656c662e6c6f636b65644e4654732e72656d6f7665286b65793a207769746864726177494429210a20202020202020207d0a0a202020207d0a0a20202020696e6974286c6f636b65644e4654547970653a20547970652c20666c6f774e4654436f6e7472616374416464726573733a20416464726573732c2065766d4e4654436f6e7472616374416464726573733a2045564d2e45564d4164647265737329207b0a2020202020202020707265207b0a2020202020202020202020206c6f636b65644e4654547970652e697353756274797065286f663a20547970653c407b4e6f6e46756e6769626c65546f6b656e2e4e46547d3e2829293a20224c6f636b6572206d75737420626520696e697469616c697a6564207769746820612076616c6964204e46542074797065220a20202020202020207d0a0a202020202020202073656c662e6c6f636b65644e465454797065203d206c6f636b65644e4654547970650a202020202020202073656c662e666c6f774e4654436f6e747261637441646472657373203d20666c6f774e4654436f6e7472616374416464726573730a202020202020202073656c662e65766d4e4654436f6e747261637441646472657373203d2065766d4e4654436f6e7472616374416464726573730a0a202020202020202073656c662e6c6f636b6572203c2d20637265617465204c6f636b657228290a202020207d0a7d0a"
        ]
    }
}