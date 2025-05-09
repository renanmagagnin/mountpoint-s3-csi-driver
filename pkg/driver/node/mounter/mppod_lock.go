package mounter

import (
	"sync"

	"k8s.io/klog/v2"
)

// MPPodLock represents a reference-counted mutex lock for Mountpoint Pod.
// It ensures synchronized access to pod-specific resources.
type MPPodLock struct {
	mutex    sync.Mutex
	refCount int
}

var (
	// mpPodLocks maps pod UIDs to their corresponding locks.
	mpPodLocks = make(map[string]*MPPodLock)

	// mpPodLocksMutex guards access to the mpPodLocks map.
	mpPodLocksMutex sync.Mutex
)

// lockMountpointPod acquires a lock for the specified pod UID and returns an unlock function.
// The returned function must be called to release the lock and cleanup resources.
//
// Parameters:
//   - uid: The unique identifier of the Mountpoint Pod to lock
//
// Returns:
//   - func(): A function that when called will unlock the pod and release associated resources
//
// Usage:
//
//	unlock := lockMountpointPod(podUID)
//	defer unlock()
func lockMountpointPod(uid string) func() {
	mpPodLock := getMPPodLock(uid)
	mpPodLock.mutex.Lock()
	return func() {
		mpPodLock.mutex.Unlock()
		releaseMPPodLock(uid)
	}
}

// getMPPodLock retrieves or creates a lock for the specified pod UID.
// It increments the reference count for existing locks.
// The caller is responsible for calling releaseMPPodLock when the lock is no longer needed.
func getMPPodLock(mpPodUID string) *MPPodLock {
	mpPodLocksMutex.Lock()
	defer mpPodLocksMutex.Unlock()

	lock, exists := mpPodLocks[mpPodUID]
	if !exists {
		lock = &MPPodLock{refCount: 1}
		mpPodLocks[mpPodUID] = lock
	} else {
		lock.refCount++
	}
	return lock
}

// releaseMPPodLock decrements the reference count for a pod's lock.
// When the reference count reaches zero, the lock is removed from the map.
// If the lock doesn't exist, the function returns silently.
func releaseMPPodLock(mpPodUID string) {
	mpPodLocksMutex.Lock()
	defer mpPodLocksMutex.Unlock()

	lock, exists := mpPodLocks[mpPodUID]
	if !exists {
		// Should never happen
		klog.Errorf("Attempted to release non-existent lock for Mountpoint Pod UID %s", mpPodUID)
		return
	}

	lock.refCount--

	if lock.refCount <= 0 {
		delete(mpPodLocks, mpPodUID)
	}
}
