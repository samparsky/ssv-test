// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../School.sol";

contract ContractTest is DSTest {
    School public testSchool;
    function setUp() public {
        testSchool = new School(address(this));
    }

    function testRegisterCourse() public {
        uint256[] memory teacherIds = new uint256[](2);
        teacherIds[0] = 1;
        teacherIds[1] = 2;

        testSchool.registerCourse("hello", teacherIds);
    }

    function testRegisterStudent() public {
        testRegisterCourse();
        bytes32 courseId = keccak256(abi.encode("hello"));
        testSchool.registerStudent("father", 10, courseId);
    }
}
