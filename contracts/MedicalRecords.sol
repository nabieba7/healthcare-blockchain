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

        function addMedicalRecord(
    address _patientAddress,
    string memory _diagnosis,
    string memory _treatment,
    string memory _medications,
    string memory _hospital
) public {
    require(patients[_patientAddress].exists, "Patient does not exist");
    
    // Check if doctor has access or is adding their own record
    require(
        hasAccess(_patientAddress, msg.sender) || msg.sender == _patientAddress,
        "No access to patient records"
    );
    
    uint256 recordId = patientRecords[_patientAddress].length;
    
    patientRecords[_patientAddress].push(MedicalRecord({
        recordId: recordId,
        diagnosis: _diagnosis,
        treatment: _treatment,
        medications: _medications,
        date: block.timestamp,
        doctorAddress: msg.sender,
        hospital: _hospital
    }));
    
    emit RecordAdded(_patientAddress, recordId, msg.sender);
}

function grantAccess(address _doctorAddress, uint256 _accessDuration) public {
    require(patients[msg.sender].exists, "Only patients can grant access");
    
    uint256 accessUntil = block.timestamp + _accessDuration;
    
    patientAccessControls[msg.sender].push(AccessControl({
        authorizedDoctor: _doctorAddress,
        accessUntil: accessUntil,
        isActive: true
    }));
    
    emit AccessGranted(msg.sender, _doctorAddress, accessUntil);
}
        
        patientAddresses.push(_patientAddress);
        emit PatientRegistered(_patientAddress, _name);
    }
    
    function getPatient(address _patientAddress) public view returns (Patient memory) {
        require(patients[_patientAddress].exists, "Patient does not exist");
        return patients[_patientAddress];
    }
