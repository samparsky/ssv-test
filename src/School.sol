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
        uint64 blockNumber;
        uint64 numberOfStudents;
        uint128 totalGrades;
    }

    /// @dev course id => course data
    mapping(bytes32 => bool) internal _courseData;

    /// @dev teacherId => courses
    mapping(uint256 => bytes32[]) internal _teacherCourses;

    /// @dev student id => course id => grade
    mapping(bytes32 => mapping(bytes32 => uint256)) internal _studentGradeData;

    /// @dev course to course grade
    // mapping(bytes32 => CourseSummary) internal _courseGradeInfo;

    /// teacher id => course id => index
    mapping(uint256 => mapping (bytes32 => uint256)) internal _teacherLastClaimSnapshotIndex;

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
    * Register students
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

        CourseSummary memory courseInfo = _getLatestCourseSummary(courseId);
        courseInfo.blockNumber = uint64(block.number);
        courseInfo.numberOfStudents += 1;
        courseInfo.totalGrades += uint128(grade);

        // Write to storage
        _studentGradeData[studentId][courseId] = grade;
        _updateCourseSummarySnapshot(courseId, courseInfo);
        
        emit NewStudent(studentId, courseId, grade);
    }

    function _updateCourseSummarySnapshot(bytes32 courseId, CourseSummary memory info) internal {
        uint256 size = _courseSummarySnapshots[courseId].length;
        // multiple snapshots within a block
        if(size > 0 && _courseSummarySnapshots[courseId][size - 1].blockNumber == block.number) {
            _courseSummarySnapshots[courseId][size - 1] = info;
        } else {
            _courseSummarySnapshots[courseId].push(info);
        }
    }

    function _getLatestCourseSummary(bytes32 courseId) internal view returns (CourseSummary memory info) {
        uint256 size = _courseSummarySnapshots[courseId].length;
        if (size > 0) {
            info = _courseSummarySnapshots[courseId][size - 1];
        }
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
        
        CourseSummary memory oldCourseInfo = _getLatestCourseSummary(oldCourseId);
        oldCourseInfo.blockNumber = uint64(block.number);
        oldCourseInfo.numberOfStudents -= 1;
        oldCourseInfo.totalGrades -= uint128(studentCurrentGrade);

        CourseSummary memory newCourseInfo = _getLatestCourseSummary(newCourseId);
        newCourseInfo.blockNumber = uint64(block.number);
        newCourseInfo.numberOfStudents += 1;
        newCourseInfo.totalGrades += uint128(newGrade);

        // @TODO take snapshot here

        delete _studentGradeData[studentId][oldCourseId];

        // Write to storage
        _studentGradeData[studentId][newCourseId] = newGrade;
        _updateCourseSummarySnapshot(oldCourseId, oldCourseInfo);
        _updateCourseSummarySnapshot(newCourseId, newCourseInfo);

        emit TransferredStudent(studentId, oldCourseId, newCourseId, newGrade);
    }


    /**
    * bulkChangeCourse change course in bulk
    */
    function bulkChangeCourse(bytes32 oldCourseId, bytes32 newCourseId, bytes32[] calldata studentIds, uint256[] calldata grades ) external onlyOwner {
        require(studentIds.length == grades.length, "INVALID_LENGTH");
        uint256 size = studentIds.length;

        for (uint256 i = 0; i < size; i++) {
            changeCourse(studentIds[i], oldCourseId, newCourseId, grades[i]);
        }
    }
    
    function getSalary(uint256 teacherId, uint256 courseId) external {
        // @TODO loop through the course summary snaphosts and evaluate the teacher salary
        // based of it
        // We can cap the size of the loop to a reasonable limit such that even if a teacher 
        // doesn't claim their salary for a long period of time they are still able to 
        // withdraw their funds gradually.
    }

    function getCourseAverageGrade(bytes32 courseId) external view returns(uint256 averageGrade) {
        CourseSummary memory oldCourseInfo = _getLatestCourseSummary(courseId);
        if (oldCourseInfo.numberOfStudents > 0) {
            averageGrade = oldCourseInfo.totalGrades / oldCourseInfo.numberOfStudents;
        }
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
            total += _getLatestCourseSummary(courses[i]).numberOfStudents;
        }
    }

    function getTeacherAverageStudentGrade(uint256 teacherId) external view returns (uint256 averageGrade) {
        bytes32[] memory courses = _teacherCourses[teacherId];
        uint256 size = courses.length;

        uint256 totalNumberOfStudents;
        uint256 totalGrades;

        for (uint256 i = 0; i < size; i++) {
            CourseSummary memory course = _getLatestCourseSummary(courses[i]);
            totalNumberOfStudents += course.numberOfStudents;
            totalGrades += course.totalGrades;
        }

        if (totalNumberOfStudents > 0) {
            averageGrade = totalGrades / totalNumberOfStudents;
        }
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
