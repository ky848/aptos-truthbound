# Truthbound

***Decentralised Prediction Market built on Optimistic Oracles***

Truthbound brings data assertion to the Aptos blockchain, using the Optimistic Oracle V3 from UMA Protocol as its foundation, where data providers can submit off-chain data for validation and make it accessible on-chain for other decentralised applications. 

Designed as an open-ended data asserter, Truthbound supports the verification of diverse data types—from financial metrics and stock prices to environmental conditions and social media trends. Each data point is tagged with a unique identifier, allowing independent verifiers to confirm its accuracy, which fosters a system of checks and balances within the blockchain ecosystem. 

Hence, unlike the Optimistic Oracle, which traditionally caters to financial data, the Data Asserter can assert any data, regardless of type, by verifying its correctness against the data ID. As described by UMA, this data Id could represent any kind of unique data identifier (a row in a database table, a validator address or a complex structure used to associate any kind of data to a given value)

With any arbitrary data set able to be asserted and brought on-chain, this makes Truthbound very suitable for supporting Decentralised Physical Infrastructure Networks (DePIN) by offering a robust way to validate off-chain data critical to these networks (such as readings from environmental sensors, IoT devices, and other physical measures). 

For instance, data related to real-world infrastructure—like energy usage or air quality—can be brought on-chain in a trusted and validated manner, enabling a wider range of applications that range from monitoring energy grids to tracking environmental conditions to be integrated with web3.

By bridging the digital and physical worlds, TruthBound enables DePIN projects to reliably bring and use all forms of data on-chain, expanding possibilities for decentralised networks to manage and verify real-world infrastructure data on the Aptos blockchain. 

![Truthbound](https://res.cloudinary.com/blockbard/image/upload/c_scale,w_auto,q_auto,f_auto,fl_lossy/v1729017483/truthbound-home-1_tlaqkp.png)

## Data Assertion Flow

This is how off-chain data may be asserted on-chain using the TruthBound Data Asserter: 

**Data Submission:**

A data provider collects off-chain data, such as environmental metrics from sensors or financial data from market sources. Each data point is then associated with a unique identifier to distinguish it from other submissions.

The data provider submits this data point along with its unique identifier to the Truthbound module. This submission includes a bond to ensure the integrity of the data, which will be returned if the data remains undisputed.

**Data Assertion and Validation:**

Once submitted, the data point enters a two-hour validation period. During this time, the data is open to verification and potential disputes. After two hours, if no disputes have been raised, the data is resolved as true and accessible for use by decentralised applications.

Independent verifiers, or disputers, can review the data to confirm its accuracy. If a verifier finds any discrepancies, they can raise a dispute, triggering the dispute resolution process.

**Dispute Resolution:**

If a dispute arises, Truthbound’s escalation manager initiates the dispute resolution process. The bond put up by the data provider acts as collateral during this phase, incentivizing accurate data submission.

The resolution process may involve further examination by other network participants or an external oracle mechanism. The escalation manager then decides whether to uphold or reject the disputed data.

If the data is found to be incorrect, the data provider’s bond is forfeited and a portion of it will be awarded to the disputer. If no dispute occurs or the data is verified as accurate, the bond is returned to the data provider.

**Finalisation and On-Chain Availability:**

After the validation period, and if no disputes are raised, the data point is confirmed as accurate and becomes permanently available on-chain. It can now be accessed and used by decentralised applications within the Aptos ecosystem.

This data assertion flow ensures that off-chain data is carefully validated before becoming an on-chain resource, enabling decentralised applications to utilise accurate and trustworthy information while maintaining transparency and accountability in the process.

## Demo MVP

The Truthbound demo is accessible at https://truthbound.xyz. The demo showcases sample data asserted that have been pre-generated for sample purposes to showcase our functionality.

The frontend demo for Truthbound is maintained in a separate repository to ensure that the Move smart contracts remain focused and well-organised. 

It can be found here: [Truthbound Frontend Github](https://github.com/0xblockbard/aptos-truthbound-frontend)

## Tech Overview and Considerations

We follow the Aptos Object Model approach, storing Data Assertion and Assertion objects on user accounts rather than on the Truthbound module to decentralise data storage, enhance scalability, and optimise gas costs. 

The Truthbound module then maintains an AssertionRegistry structs that maps assertion IDs to their creators respectively. 

While the Truthbound Data Asserter and Escalation Manager modules are based on UMA Protocol’s Solidity contracts, there are some significant differences between them. 

Firstly, instead of inheriting the Optimistic Oracle V3 contract in the prediction market contract like in Solidity, we have integrated the Optimistic Oracle functionality and Data Asserter functionalities into a single module. This is then deployed together with the Escalation Manager module as a single package. 

Secondly, while preserving the underlying architecture as closely as possible, we have simplified the assertion IDs from keccak hashes to u64 IDs for easier data retrieval. 

UMA Protocol’s Solidity smart contracts referenced:

- [Optimistic Oracle V3](https://github.com/UMAprotocol/protocol/blob/master/packages/core/contracts/optimistic-oracle-v3/implementation/OptimisticOracleV3.sol)
- [Full Policy Escalation Manager](https://github.com/UMAprotocol/protocol/blob/master/packages/core/contracts/optimistic-oracle-v3/implementation/escalation-manager/FullPolicyEscalationManager.sol)
- [Data Asserter](https://github.com/UMAprotocol/dev-quickstart-oov3/blob/master/src/DataAsserter.sol)

## Smart Contract Entrypoints

The Truthbound Data Asserter module includes three public entrypoints and one admin entrypoint:

**Data Asserter Public Entrypoints**

1. **assert_data_for**: Allows a user to assert data 
   - **Input**: Data id and data
   - **Output**: Creates a new Data Assertion

2. **dispute_assertion**: Allows a user to dispute a data assertion. If whitelisted disputes are enabled on the escalation manager, the user will need to be whitelisted in order to call this entrypoint.
   - **Input**: Assertion ID
   - **Output**: Raises a new dispute for the assertion, requiring the escalation manager admin to set an arbitration resolution to resolve the dispute

3. **settle_assertion**: Allows any user to settle an assertion after it has been resolved. If there are no disputes, the assertion is resolved as true and the asserter receives the bond. If the assertion has been disputed, the assertion is resolved depending on the result. Based on the result, the asserter or disputer receives the bond. If the assertion was disputed then an amount of the bond is sent to a treasury as a fee based on the burnedBondPercentage. The remainder of the bond is returned to the asserter or disputer.
   - **Input**: Assertion ID
   - **Output**: Resolves assertion and handles disbursement of the bond

**Data Asserter Admin Entrypoints**

1. **set_admin_properties**: Allows the Truthbound admin to update the module admin properties or config (min_liveness, default_fee, treasury_address, burned_bond_percentage, currency_metadata)
   - **Input**: Verifies that the signer is the admin and that the burned_bond_percentage is greater than 0 and less than 10000 (100%)
   - **Output**: Updates the Truthbound module admin properties

<br />

The Truthbound Escalation Manager module includes four admin entrypoints:
 
<br />

**Escalation Manager Admin Entrypoints**

1. **set_assertion_policy**: Allows the Escalation Manager admin to set the assertion policy that the prediction market module will follow  
   - **Input**: Verifies that the signer is the admin and new boolean policy values (block_assertion, validate_asserters, validate_disputers)
   - **Output**: Updates the Escalation Manager assertion policy

2. **set_whitelisted_asserter**: Allows the Escalation Manager admin to set a whitelisted asserter with a given boolean representing the whitelisted asserter’s permission
   - **Input**: Verifies that the signer is the admin
   - **Output**: Sets whitelisted asserter

3. **set_whitelisted_dispute_caller**: Allows the Escalation Manager admin to set a whitelisted disputer with a given boolean representing the whitelisted disputer’s permission
   - **Input**: Verifies that the signer is the admin
   - **Output**: Sets whitelisted disputer

4. **set_arbitration_resolution**: Allows the Escalation Manager admin to resolve a market assertion outcome in the event of a dispute. This function has been customised to allow for an override for greater control and flexibility.
   - **Input**: Verifies that the signer is the admin and derives the resolution request based on the assertion’s timestamp, market identifier, and ancillary data
   - **Output**: Sets an arbitration resolution


## Code Coverage

Truthbound has comprehensive test coverage, with 100% of the codebase thoroughly tested. This includes a full range of scenarios that ensure the platform's reliability and robustness.

The following section provides a breakdown of the tests that validate each function and feature, affirming that Truthbound performs as expected under all intended use cases.

![Code Coverage](https://res.cloudinary.com/blockbard/image/upload/c_scale,w_auto,q_auto,f_auto,fl_lossy/v1728976608/truthbound-code-coverage_knrwhh.png)

## Future Plans

Looking ahead, here are some plans to expand the features and capabilities of Truthbound in Phase 2. 

### Planned Features:

- **Expanding DePIN Integration:** Deepen Truthbound’s capabilities within Decentralized Physical Infrastructure Networks (DePIN) by incorporating additional data sources, such as advanced IoT sensors, weather stations, and renewable energy systems, to support a wider range of real-world applications.

- **Extend use of bond with alternative tokens**: Currently, only one specified token may be used as the bond for either the asserter or disputer. We would extend this to allow for other alternative tokens to be used as the bond instead, which would allow other dApps to utilise our oracles for their business objectives with their native tokens.

- **Developing a Data Verification Mechanism (DVM):** With more time and resources, we would also be able to establish a Data Verification Mechanism (DVM) similar to UMA Protocol’s, which would provide an additional layer of dispute resolution for Truthbound. In the event of a dispute, a voting process could be initiated, allowing Aptos tokenholders to collectively verify data accuracy by referencing predefined methods and off-chain sources. This would not only introduce a human judgment element but also ensure economic security by making manipulation cost-prohibitive. The DVM would enhance Truthbound's reliability and serve as a safeguard for projects requiring accurate and resilient data validation.

- **Improved User Interface and Developer Tools:** Launch an intuitive dashboard for data providers, verifiers, and developers, simplifying access to data assertion functionalities. Additional developer tools and APIs could facilitate easier integration with dApps and other blockchain projects.


## Conclusion

Leveraging our adaptation of UMA Protocol’s Optimistic Oracle V3 to Move, Truthbound serves as a robust bridge between off-chain data and on-chain verification within the Aptos ecosystem.  

With our package, we will be able to provide a flexible framework tailored to Decentralised Physical Infrastructure Networks (DePIN) and other applications that require secure, validated data from real-world sources.

With mechanisms for dispute resolution, Truthbound is well-suited for dApps that depend on reliable data — be it for environmental monitoring, energy management, or other infrastructure-focused uses. 

As the demand for trustworthy data grows, Truthbound’s capability to bring physical-world insights to the blockchain helps broaden the scope of possible decentralizsd applications that can be built on Aptos, empowering innovation with confidence.

By prioritising both accuracy and data integrity, Truthbound is poised to become a cornerstone in the development of blockchain-based, data-driven solutions on Aptos.

## Credits and Support

Thanks for reading till the end!

Truthbound is designed and built by 0xBlockBard, a solo indie maker passionate about building innovative products in the web3 space. 

With over 10 years of experience, my work spans full-stack and smart contract development, with the Laravel Framework as my go-to for web projects. I’m also familiar with Solidity, Rust, LIGO, and most recently, Aptos Move.

Beyond coding, I occasionally write and share insights on crypto market trends and interesting projects to watch. If you are interested to follow along my web3 journey, you can subscribe to my [Substack](https://www.0xblockbard.com/) here :)

Twitter / X: [0xBlockBard](https://x.com/0xblockbard)

Substack: [0xBlockBard Research](https://www.0xblockbard.com/)