
# Truthbound

**_Decentralised Prediction Market built on Optimistic Oracles_**

Truthbound brings data assertion to the Aptos blockchain, using the Optimistic Oracle V3 from UMA Protocol as its foundation. Data providers can submit off-chain data for validation, making it accessible on-chain for decentralised applications.

Designed as an open-ended data asserter, Truthbound supports the verification of diverse data types—from financial metrics and stock prices to environmental conditions and social media trends. Each data point is tagged with a unique identifier, allowing independent verifiers to confirm its accuracy.

Unlike the Optimistic Oracle, which primarily focuses on financial data, Truthbound can assert any data type by verifying its correctness against a unique identifier. This flexibility makes it well-suited for Decentralised Physical Infrastructure Networks (DePIN), ensuring reliable validation of off-chain data critical to these networks.

## Data Assertion Flow

**Data Submission:** A data provider collects off-chain data and assigns a unique identifier. This data is submitted to the Truthbound module along with a bond to ensure data integrity.

**Data Assertion and Validation:** The data undergoes a validation period where independent verifiers can confirm its accuracy or raise disputes. If undisputed, the data is resolved as true and made accessible.

**Dispute Resolution:** If a dispute arises, the escalation manager handles resolution. If the data is incorrect, the provider forfeits their bond. If verified as accurate, the bond is returned.

**Finalisation and On-Chain Availability:** Once validated, the data is permanently accessible on-chain for decentralised applications.

## Tech Overview

Truthbound follows the Aptos Object Model approach, storing assertions on user accounts rather than the module for decentralisation and scalability. AssertionRegistry maps assertion IDs to their creators.

Truthbound integrates Optimistic Oracle functionality and Data Asserter capabilities into a single module, deployed alongside the Escalation Manager. Assertion IDs have been simplified for easier retrieval.

## Smart Contract Entrypoints

### Data Asserter Public Entrypoints

1.  **assert_data_for** – Submits data with a unique identifier.
    
2.  **dispute_assertion** – Raises a dispute against an assertion.
    
3.  **settle_assertion** – Resolves assertions and manages bond disbursement.
    

### Data Asserter Admin Entrypoint

-   **set_admin_properties** – Updates module admin properties.
    

### Escalation Manager Admin Entrypoints

1.  **set_assertion_policy** – Defines the assertion policy.
    
2.  **set_whitelisted_asserter** – Manages whitelisted asserters.
    
3.  **set_whitelisted_dispute_caller** – Manages whitelisted disputers.
    
4.  **set_arbitration_resolution** – Handles dispute resolution.
    

## Future Plans

-   Expanding DePIN integration with additional data sources.
    
-   Supporting alternative tokens for bond deposits.
    
-   Developing a Data Verification Mechanism (DVM) for additional dispute resolution.
    
-   Enhancing the user interface and developer tools for better accessibility.
    

## Conclusion

Truthbound bridges off-chain data and on-chain verification on Aptos, providing a robust solution for DePIN and other applications requiring validated real-world data. Its dispute resolution mechanisms make it ideal for decentralised applications dependent on trustworthy data.

By ensuring accuracy and data integrity, Truthbound strengthens blockchain-based, data-driven solutions, empowering decentralised innovation with confidence.
