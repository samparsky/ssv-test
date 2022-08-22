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

        testSchool.registerCourse("math", teacherIds);
        testSchool.registerCourse("biology", teacherIds);
    }

    function testRegisterStudent() public {
        testRegisterCourse();
        bytes32 courseId = keccak256(abi.encode("math"));
        testSchool.registerStudent("father", 10, courseId);
    }

    function testChangeCourse() public {
        testRegisterStudent();
        bytes32 studentId = keccak256(abi.encode("father"));
        bytes32 oldCourseId = keccak256(abi.encode("math"));
        bytes32 newCourseId = keccak256(abi.encode("biology"));
        testSchool.changeCourse(studentId, oldCourseId, newCourseId, 5);

        assertEq(testSchool.getCourseAverageGrade(newCourseId), 5);
        assertEq(testSchool.getTeacherStudentCount(1), 1);
        assertEq(testSchool.getTeacherAverageStudentGrade(1), 5);
    }
}
