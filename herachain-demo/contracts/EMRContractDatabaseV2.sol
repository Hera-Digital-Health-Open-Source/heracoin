// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./HeraCoinRewarder.sol";
import "./EMRStorageContractV2.sol";

contract EMRContractDatabaseV2 {
    //Reward Contract
    HeraCoinRewarder private rewarder;

    //list of authorized addresses for calling transactions on this contract
    mapping(address => bool) private authorized_addresses;

    //Mapping of a patient's MD5 Hash to the integer IDs of their EMRContracts
    mapping(bytes32 => address) public patientsToEMRStorage;

    event EMRCreated(address patient, uint256 record_id);
    event SentRewardTokens(
        uint256 amount,
        address fromAccount,
        address toAccount,
        uint256 totalBalance
    );

    //Modifier that checks if an address is authorized
    modifier isAuthorizedAddress(address check) {
        require(authorized_addresses[check]);
        _;
    }

    // constructor(HeraCoinRewarder _rewarder) {
    //     rewarder = _rewarder;
    // }

    constructor() {
        authorized_addresses[msg.sender] = true;
    }

    function createEMRStorage(
        bytes32 patient_hash
    ) public isAuthorizedAddress(msg.sender) returns (bool) {
        //The database can build the EMRStorageContract
        if (patientsToEMRStorage[patient_hash] != address(0x0)) {
            revert("An EMRStorageContract already exists for this patient");
        }

        EMRStorageContractV2 new_emr_storage = new EMRStorageContractV2(
            this,
            patient_hash
        );

        //Maps the new EMRStorage to the Patient Hash
        patientsToEMRStorage[patient_hash] = address(new_emr_storage);

        return true;
    }

    function createEMRStorageInternal(
        bytes32 patient_hash
    ) internal isAuthorizedAddress(msg.sender) returns (bool) {
        //The database can build the EMRStorageContract
        if (patientsToEMRStorage[patient_hash] != address(0x0)) {
            revert("An EMRStorageContract already exists for this patient");
        }

        EMRStorageContractV2 new_emr_storage = new EMRStorageContractV2(
            this,
            patient_hash
        );

        //Maps the new EMRStorage to the Patient Address
        patientsToEMRStorage[patient_hash] = address(new_emr_storage);

        //Rewards the patient for creating an EMR using the Rewarder contract
        return true;
    }

    function sendRewardForEmrCreation(address patient) public {
        rewarder.sendRewardForEmrCreation(payable(patient));
    }

    function createEMR(
        bytes32 memory patient_hash,
        string memory _record_type,
        string memory _record_status,
        uint256 _record_date,
        string memory _ipfs_image_hash,
        string memory _ipfs_data_hash
    ) public isAuthorizedAddress(msg.sender) returns (bool) {
        //Check if an address exists for an EMR Storage contract for that patient
        if (patientsToEMRStorage[patient_hash] == address(0x0)) {
            createEMRStorageInternal(patient_hash);
        }

        //Then create a new record struct in the newly created contract
        EMRStorageContractV2 storageContract = EMRStorageContractV2(
            patientsToEMRStorage[patient_hash]
        );
        storageContract.addRecordFromDatabase(
            _record_type,
            _record_status,
            _record_date,
            _ipfs_image_hash,
            _ipfs_data_hash
        );

        return true;
    }

    function getEMRStorageContract(
        bytes32 patient_hash
    ) public view isAuthorizedAddress(msg.sender) returns (address) {
        return patientsToEMRStorage[patient_hash];
    }

    function addAuthorizedAddress(address add) public onlyOwner returns (bool) {
        if (!authorized_addresses[add]) {
            authorized_addresses[add] = true;
        }
        return true;
    }

    function removeAuthorizedAddress(
        address add
    ) public onlyOwner returns (bool) {
        delete authorized_addresses[add];
        return true;
    }

    // Used to transfer ownership of EMRStorageContract to a new address and remove from the EMRContractDatabase
    function exportEMRStorageContract(
        bytes32 patient_hash,
        address to_address
    ) public onlyOwner returns (bool) {
        if (patientsToEMRStorage[patient_hash] == address(0x0)) {
            revert();
        }
        EMRStorageContractV2 storageContract = EMRStorageContractV2(
            patientsToEMRStorage[patient_hash]
        );

        storageContract.transferOwnership(to_address);
        delete patientsToEMRStorage[patient_hash];
    }
}
