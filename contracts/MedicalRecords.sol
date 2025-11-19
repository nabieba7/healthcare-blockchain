// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

contract MedicalRecords {
    address public admin;
    uint256 recordId;
    string diagnosis;
    string treatment;
    string medications;
    uint256 date;
    address doctorAddress;
    string hospital;
}
    
    struct Patient {
        address walletAddress;
        string name;
        uint256 dateOfBirth;
        bool exists;
    }
    struct AccessControl {
    address authorizedDoctor;
    uint256 accessUntil;
    bool isActive;
}
    
    mapping(address => Patient) public patients;
    address[] public patientAddresses;
    mapping(address => MedicalRecord[]) private patientRecords;
    mapping(address => AccessControl[]) private patientAccessControls;
    
    event PatientRegistered(address indexed patientAddress, string name);
    event RecordAdded(address indexed patient, uint256 recordId, address doctor);
event AccessGranted(address indexed patient, address indexed doctor, uint256 until);
    
    constructor() {
        admin = msg.sender;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    function registerPatient(
        address _patientAddress, 
        string memory _name, 
        uint256 _dateOfBirth
    ) public onlyAdmin {
        require(!patients[_patientAddress].exists, "Patient already registered");
        
        patients[_patientAddress] = Patient({
            walletAddress: _patientAddress,
            name: _name,
            dateOfBirth: _dateOfBirth,
            exists: true
        });
        
        patientAddresses.push(_patientAddress);
        emit PatientRegistered(_patientAddress, _name);
    }
    
    function getPatient(address _patientAddress) public view returns (Patient memory) {
        require(patients[_patientAddress].exists, "Patient does not exist");
        return patients[_patientAddress];
    }
