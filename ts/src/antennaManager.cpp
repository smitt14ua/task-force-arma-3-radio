#include "antennaManager.h"
#include "task_force_radio.hpp"

AntennaManager::AntennaManager() {
    TFAR::getInstance().doDiagReport.connect([this](std::stringstream& diag) {

#define logParamN(n,x) diag << TS_INDENT << #n << " " << (x) << "\n"
#define logParamT(n,x) diag << TS_INDENT << TS_INDENT << #n << " " << (x) << "\n"

        diag << "AM:\n";
        LockGuard_shared lock(m_lock);
        for (auto& it : antennas) {

            logParamN(oid, it->getID().getObjID());
            logParamT(creator, it->getID().getCreator());
            logParamT(pos, it->getPos().toString());
            logParamT(rng, it->getRange());
            logParamT(sat, it->hasSatelliteUplink());
        }
    });
}

AntennaConnection AntennaManager::findConnection(const Position3D& from, float maxDistanceToAnt, const Position3D& to) {
    LockGuard_shared slock(m_lock);
    std::shared_ptr<Antenna> bestAntenna = nullptr;
    float lowestLoss = 1.f;

    const float maxDistToAntSquared = maxDistanceToAnt*maxDistanceToAnt;

    //#TODO better algo...?
    for (auto& ant : antennas) {
        //Only antennas that can be reached by sender / reach to receiver (no per voice packet allocation)
        if (!ant->canBeReachedBy(from, maxDistToAntSquared) || !ant->canReach(to)) continue;
        const auto loss = ant->connectionLoss(from, maxDistanceToAnt, to);
        if (loss < lowestLoss) {
            bestAntenna = ant;
            lowestLoss = loss;
        }
    }
    if (bestAntenna)
        return AntennaConnection(from, bestAntenna, to, lowestLoss);
    return AntennaConnection();
}

void AntennaManager::addAntenna(Antenna ant) {
    if (ant.getID().isNull()) return;
    LockGuard_exclusive lock(m_lock);
    const auto found = findAntenna(ant);
    if (found != antennas.end()) {
        //Replace instead of modifying in place: connections handed out earlier may still read the old one
        *found = std::make_shared<Antenna>(std::move(ant));
        return;
    }
    antennas.push_back(std::make_shared<Antenna>(std::move(ant)));
}

void AntennaManager::removeAntenna(const NetID& antennaID) {
    if (antennaID.isNull()) return;
    LockGuard_exclusive lock(m_lock);
    const auto found = findAntenna(antennaID);
    if (found == antennas.end()) return;
    antennas.erase(found);
}

void AntennaManager::clearAntennas() {
    LockGuard_exclusive lock(m_lock);
    antennas.clear();
}

std::vector<std::shared_ptr<Antenna>>::iterator AntennaManager::findAntenna(const NetID& antennaID) {
    return std::_Find_pr(antennas.begin(), antennas.end(), antennaID, [](const auto& left, const NetID & right) {return *left == right; });
}
