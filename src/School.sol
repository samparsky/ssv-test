// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract School is Ownable {

    /// @dev maximum number of courses a teacher can teach
    uint256 constant public MAXIMUM_TEACHER_COURSES = 15;

    /// @dev teacher salary per second
    uint256 constant public TEACHER_SALARY_PER_BLOCK = 1;

    // /// @dev teacher 
    // struct Course {
    //     uint256 numberOfStudents;
    //     uint256[] teacherIds;
    // }

    struct CourseSummary {
        uint128 numberOfStudents;
        uint128 totalGrades;
    }

    /// @dev course id => course data
    mapping(bytes32 => bool) internal _courseData;

    /// @dev teacherId => courses
    mapping(uint256 => bytes32[]) internal _teacherCourses;

    /// @dev student id => course id => grade
    mapping(bytes32 => mapping(bytes32 => uint256)) internal _studentGradeData;

    /// @dev course to course grade
    mapping(bytes32 => CourseSummary) internal _courseGradeInfo;

    /// teacher id => courese id => block number
    mapping(uint256 => mapping (bytes32 => uint256)) internal _teacherLastClaimBlock;

    /// course snapshot
    /// course id => block number => course summary
    mapping(bytes32 => CourseSummary[]) internal _courseSummarySnapshots;

    constructor(address admin) Ownable() {
        _transferOwnership(admin);
    }

    /**
    * Register course
    * @param name course name
    * @param teacherIds ids of the teachers teaching the course
    */
    function registerCourse(string calldata name, uint256[] calldata teacherIds) external onlyOwner {
        bytes32 courseId = keccak256(abi.encode(name));

        // ensure the course does not exist
        require(!_courseData[courseId], "COURSE_EXISTS");

        // Write to storage
        _courseData[courseId] = true;

        for(uint256 i = 0; i < teacherIds.length; i++) {
            uint256 teacherId = teacherIds[i];
            uint256 size = _teacherCourses[teacherId].length;
            // ensure it doesn't exceed maximum
            require(size < MAXIMUM_TEACHER_COURSES, "TOO_MUCH_COURSES");
            _teacherCourses[teacherId].push(courseId);

            emit RegisterCourse(courseId, teacherId);
        }
    }

    /**
    * Register stude
    *
    * @param name student name
    * @param grade student grade out of a 100
    * @param courseId course id 
    */
    function registerStudent(string calldata name, uint256 grade, bytes32 courseId) external onlyOwner {
        bytes32 studentId = keccak256(abi.encode(name));
        /// check if course exists
        require(_courseData[courseId], "COURSE_EXISTS");
        /// check if student exists
        require(_studentGradeData[studentId][courseId] == 0, "STUDENT_EXISTS");

        CourseSummary memory courseInfo = _courseGradeInfo[courseId];
        courseInfo.numberOfStudents += 1;
        courseInfo.totalGrades += uint128(grade);

        // Write to storage
        _studentGradeData[studentId][courseId] = grade;
        _courseGradeInfo[courseId] = courseInfo;
        
        // Take Snapshots here
        // _courseSummarySnapshots[courseId][block.number] = courseInfo;
        emit NewStudent(studentId, courseId, grade);
    }

    /**
    * Change student course
    *
    * @param studentId student id
    * @param oldCourseId student old course id
    * @param newCourseId student new course id
    * @param newGrade new grade 
    */
    function changeCourse(bytes32 studentId, bytes32 oldCourseId, bytes32 newCourseId, uint256 newGrade) public onlyOwner {
        // @TODO check if the student is already registered to change course
        uint256 studentCurrentGrade = _studentGradeData[studentId][oldCourseId];
        require(studentCurrentGrade > 0, "STUDENT_NOT_EXISTS");
        
        CourseSummary memory oldCourseInfo = _courseGradeInfo[oldCourseId];
        oldCourseInfo.numberOfStudents -= 1;
        oldCourseInfo.totalGrades -= uint128(studentCurrentGrade);
        
        // @TODO take snapshot here

        CourseSummary memory newCourseInfo = _courseGradeInfo[newCourseId];
        newCourseInfo.numberOfStudents += 1;
        newCourseInfo.totalGrades += uint128(newGrade);

        // @TODO take snapshot here

        delete _studentGradeData[studentId][oldCourseId];

        // Write to storage
        _studentGradeData[studentId][newCourseId] = newGrade;
        _courseGradeInfo[oldCourseId] = oldCourseInfo;
        _courseGradeInfo[newCourseId] = newCourseInfo;

        emit TransferredStudent(studentId, oldCourseId, newCourseId, newGrade);
    }


    /**
    *
    *
    *
    *
    */
    function bulkChangeCourse(bytes32 oldCourseId, bytes32 newCourseId, bytes32[] calldata studentIds, uint256[] calldata grades ) external onlyOwner {
        require(studentIds.length == grades.length, "INVALID_LENGTH");
        uint256 size = studentIds.length;

        for (uint256 i = 0; i < size; i++) {
            changeCourse(studentIds[i], oldCourseId, newCourseId, grades[i]);
        }
    }
    
    function getSalary(uint256 teacherId, uint256 courseId) external {

    }

    function getCourseAverageGrade(bytes32 courseId) external view returns(uint256 averageGrade) {
        CourseSummary memory oldCourseInfo = _courseGradeInfo[courseId];
        averageGrade = oldCourseInfo.totalGrades / oldCourseInfo.numberOfStudents;
    }

    /**
    *
    * Get teacher student count
    * @param teacherId teacher id
    */
    function getTeacherStudentCount(uint256 teacherId) external view returns (uint256 total) {
        bytes32[] memory courses = _teacherCourses[teacherId];
        uint256 size = courses.length;
        
        for (uint256 i = 0; i < size; i++) {
            total += _courseGradeInfo[courses[i]].numberOfStudents;
        }
    }

    function getTeacherAverageStudentGrade(uint256 teacherId) external view returns (uint256 averageGrade) {
        bytes32[] memory courses = _teacherCourses[teacherId];
        uint256 size = courses.length;

        uint256 totalNumberOfStudents;
        uint256 totalGrades;

        for (uint256 i = 0; i < size; i++) {
            CourseSummary memory course = _courseGradeInfo[courses[i]];
            totalNumberOfStudents += course.numberOfStudents;
            totalGrades += course.totalGrades;
        }

        averageGrade = totalGrades / totalNumberOfStudents;
    }

    /**
    * Emitted on new student registered
    *
    * @param studentId id of student registered
    * @param courseId course id student is registering
    * @param grade student grade 
    */
    event NewStudent(bytes32 indexed studentId, bytes32 courseId, uint256 grade);

    /**
    * Emitted on student transfer
    *
    * @param oldCourseId id of student registered
    * @param newCourseId course id student is registering
    * @param newGrade student grade 
    */
    event TransferredStudent(bytes32 indexed studentId, bytes32 oldCourseId,  bytes32 newCourseId, uint256 newGrade);

    /// Emitted on registerCourse
    event RegisterCourse(bytes32 courseId, uint256 teacherId);
}
